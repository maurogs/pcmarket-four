# One store's slice of a checkout (multi-seller carts fan out into one order
# per store, linked by checkout_group). State machine (AASM):
#
#   pending → paid → shipped → delivered → completed
#      ↓        ↓        ↓         ↓  ↘
#   cancelled refunded ← (paid/shipped/delivered/disputed)  disputed ⇄
#
# Money columns are cents snapshotted at placement time (see Orders::Placer);
# addresses are jsonb snapshots so later address-book edits never rewrite
# history. Bang events persist (see the AASM gotcha in Listing).
class Order < ApplicationRecord
  include AASM

  STATUSES = %w[pending paid shipped delivered completed cancelled refunded disputed].freeze
  PAYMENT_STATUSES = %w[unpaid paid refunded partially_refunded].freeze
  PAYMENT_METHODS = %w[manual stripe].freeze
  SHIPPING_METHODS = %w[delivery pickup].freeze

  # Buyer protection window: how long after delivery the buyer may still
  # dispute before the order auto-completes. Overridable through the
  # `buyer_protection_days` Setting when one exists.
  AUTO_COMPLETE_DAYS = 2

  # Guest checkouts keep buyer_id NULL and are tracked by buyer_email.
  belongs_to :buyer, class_name: "User", optional: true
  belongs_to :store
  has_many :order_items, dependent: :destroy

  validates :number, presence: true, uniqueness: true
  validates :buyer_email, presence: true, length: { maximum: 254 }
  validates :status, inclusion: { in: STATUSES }
  validates :payment_status, inclusion: { in: PAYMENT_STATUSES }
  validates :payment_method, inclusion: { in: PAYMENT_METHODS }
  validates :shipping_method, inclusion: { in: SHIPPING_METHODS }, allow_nil: true
  validates :currency, presence: true, format: { with: Listing::CURRENCY_CODE }
  validates :subtotal_cents, :shipping_cents, :discount_cents, :total_cents, :commission_cents,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :commission_percent,
    numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :shipping_address, presence: true
  validate :tracking_number_present_for_shipment, if: :tracking_required?

  before_validation :generate_number, on: :create

  # NOTE: transition callbacks go on the EVENT (before:), not on
  # `transitions` — AASM 6 silently ignores a `before:` there.
  aasm column: :status do
    state :pending, initial: true
    state :paid, :shipped, :delivered, :completed, :cancelled, :refunded, :disputed

    event :mark_paid, before: :apply_paid do
      transitions from: :pending, to: :paid
    end

    # ship!(tracking) — tracking is a hash of tracking_number/carrier/url.
    # Pickup orders may ship without a tracking number.
    event :ship, before: :apply_shipment do
      transitions from: :paid, to: :shipped
    end

    event :confirm_delivery, before: :apply_delivery do
      transitions from: :shipped, to: :delivered
    end

    event :complete, before: :apply_completion do
      transitions from: :delivered, to: :completed
    end

    # cancel!(reason) — both source states are pre-shipment, so the stock
    # always goes back to the listings.
    event :cancel, before: :apply_cancellation do
      transitions from: [ :pending, :paid ], to: :cancelled
    end

    # refund! — restocks only when the goods never left the seller.
    event :refund, before: :apply_refund do
      transitions from: [ :paid, :shipped, :delivered, :disputed ], to: :refunded
    end

    event :open_dispute do
      transitions from: [ :shipped, :delivered ], to: :disputed
    end

    # resolve_dispute!(outcome: "refunded"|"completed") — buyer or seller
    # wins; the first matching transition wins, so the default is completed.
    # The outcome MUST be a hash: AASM reads a first positional argument that
    # matches a target state name ("refunded") as the to-state instead.
    event :resolve_dispute, before: :apply_resolution do
      transitions from: :disputed, to: :refunded, if: ->(opts = {}) { dispute_for_buyer?(opts) }
      transitions from: :disputed, to: :completed
    end
  end

  scope :for_buyer, ->(user) { where(buyer_id: user.id) }
  scope :for_store, ->(store) { where(store_id: store.id) }
  scope :placed, -> { where.not(placed_at: nil).order(placed_at: :desc, id: :desc) }
  scope :active, -> { where(status: %w[pending paid shipped delivered disputed]) }

  # Buyer protection window in days (Setting override, else the constant).
  def self.auto_complete_days
    days = AppSettings.get("buyer_protection_days")
    days.present? ? Integer(days) : AUTO_COMPLETE_DAYS
  end

  def buyer?(user)
    user.present? && buyer_id.present? && buyer_id == user.id
  end

  def seller?(user)
    user.present? && store.user_id == user.id
  end

  # The buyer may cancel while the order has not shipped; sellers/admins
  # handle the rest through moderation.
  def can_be_cancelled_by?(user)
    buyer?(user) && may_cancel?
  end

  def status_label
    I18n.t("activerecord.attributes.order.statuses.#{status}", default: status.humanize)
  end

  def payment_status_label
    I18n.t("activerecord.attributes.order.payment_statuses.#{payment_status}",
      default: payment_status.humanize)
  end

  private

  # --- AASM transition callbacks ---------------------------------------------

  def apply_paid
    self.paid_at ||= Time.current
    self.payment_status = "paid"
  end

  def apply_shipment(tracking = {})
    tracking = tracking.to_h.symbolize_keys
    self.tracking_number = tracking[:tracking_number].presence || tracking_number
    self.tracking_carrier = tracking[:tracking_carrier].presence || tracking_carrier
    self.tracking_url = tracking[:tracking_url].presence || tracking_url
    self.shipped_at = Time.current
  end

  def apply_delivery
    self.delivered_at = Time.current
    self.auto_complete_at = delivered_at + self.class.auto_complete_days.days
  end

  def apply_completion
    self.completed_at ||= Time.current
  end

  def apply_cancellation(reason = nil)
    self.cancel_reason = reason.presence
    self.cancelled_at = Time.current
    restock_listings
  end

  def apply_refund
    self.refunded_at = Time.current
    self.payment_status = "refunded"
    restock_listings if pre_shipment?
  end

  # resolve_dispute!(outcome:): the buyer wins ("refunded") or the seller
  # does ("completed").
  def apply_resolution(opts = {})
    if dispute_for_buyer?(opts)
      apply_refund
    else
      apply_completion
    end
  end

  def dispute_for_buyer?(opts)
    opts = opts.to_h
    (opts[:outcome] || opts["outcome"]).to_s == "refunded"
  end

  # --- Restock ---------------------------------------------------------------

  # The DB still holds the pre-transition status when a bang event runs its
  # before callback (aasm.from_state is only set during transition
  # selection, after it), so the persisted value is the source of truth.
  def pre_shipment?
    %w[pending paid].include?(status_in_database.presence || status)
  end

  # Puts the units back on sale: listings that this order marked sold go back
  # to published (their quantity was never decremented), the rest just get
  # the purchased units added back.
  def restock_listings
    order_items.includes(:listing).each do |item|
      listing = item.listing
      next if listing.nil?

      if item.sold_listing?
        listing.relist! if listing.sold?
      elsif !listing.sold?
        listing.update!(quantity: listing.quantity + item.quantity)
      end
    end
  end

  # --- Validations -----------------------------------------------------------

  def tracking_required?
    shipped? && shipping_method != "pickup"
  end

  def tracking_number_present_for_shipment
    errors.add(:tracking_number, :required_for_shipping) if tracking_number.blank?
  end

  # --- Number ------------------------------------------------------------------

  # "PCM-2611-483920" — marketplace prefix, YYMM of placement, random six
  # digits; retried until unique (the DB unique index is the backstop).
  def generate_number
    return if number.present?

    prefix = "PCM-#{Time.current.strftime("%y%m")}-"
    loop do
      candidate = "#{prefix}#{format("%06d", SecureRandom.random_number(1_000_000))}"
      unless self.class.where(number: candidate).exists?
        self.number = candidate
        break
      end
    end
  end
end
