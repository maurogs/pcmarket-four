class Order < ApplicationRecord
  NUMBER_PREFIX = "PCM"
  NUMBER_SEQUENCE = "order_number_seq".freeze
  FILTERS = {
    "all" => nil,
    "to_pay" => %w[pending_payment],
    "in_progress" => %w[paid shipped delivered],
    "completed" => %w[completed],
    "cancelled" => %w[cancelled refunded]
  }.freeze

  belongs_to :buyer, class_name: "User", optional: true, inverse_of: :orders_as_buyer
  belongs_to :seller, class_name: "User", inverse_of: :orders_as_seller
  belongs_to :store, optional: true, inverse_of: :orders

  has_many :order_items, dependent: :destroy, inverse_of: :order
  has_many :listings, through: :order_items
  has_one :review, dependent: :destroy, inverse_of: :order

  has_secure_token :guest_access_token

  enum :status, {
    pending_payment: 0,
    paid: 1,
    shipped: 2,
    delivered: 3,
    completed: 4,
    cancelled: 5,
    refunded: 6,
    disputed: 7
  }
  enum :fulfilment, { shipping: 0, local_pickup: 1 }

  before_validation :assign_number, on: :create

  validates :number, presence: true, uniqueness: true
  validates :subtotal_cents, :shipping_cents, :commission_cents, :total_cents,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :buyer_email, presence: true, if: :guest?
  validates :buyer_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :payment_method, inclusion: { in: %w[bank_transfer cash_on_pickup stripe] },
                             allow_nil: true

  scope :for_buyer, ->(user) { where(buyer_id: user.id) }

  def self.buyer_orders(user, filter: "all", query: nil)
    scope = for_buyer(user)
    statuses = FILTERS[filter.to_s]
    scope = scope.where(status: statuses) if statuses

    if query.present?
      pattern = "%#{sanitize_sql_like(query.to_s.strip)}%"
      scope = scope.left_joins(:order_items)
                   .where("orders.number ILIKE :q OR order_items.title_snapshot ILIKE :q", q: pattern)
                   .distinct
    end

    scope.includes(:store, :seller, order_items: { listing: { images_attachments: :blob } })
         .order(created_at: :desc)
  end

  # Atomic order numbers. The sequence is created by a migration; the pg_class
  # check also covers test databases prepared from schema (which does not dump
  # standalone sequences).
  def self.next_number
    unless sequence_exists?
      connection.execute("CREATE SEQUENCE IF NOT EXISTS #{NUMBER_SEQUENCE}")
      highest = connection.select_value(
        "SELECT COALESCE(MAX(split_part(number, '-', 3)::bigint), 0) FROM orders " \
        "WHERE number ~ '^PCM-[0-9]{4}-[0-9]+$'"
      ).to_i
      if highest.positive?
        connection.execute("SELECT setval('#{NUMBER_SEQUENCE}', #{highest}, true)")
      else
        connection.execute("SELECT setval('#{NUMBER_SEQUENCE}', 1, false)")
      end
    end

    connection.select_value("SELECT nextval('#{NUMBER_SEQUENCE}')").to_i
  end

  def self.sequence_exists?
    connection.select_value(
      "SELECT COUNT(*) FROM pg_class WHERE relname = '#{NUMBER_SEQUENCE}' AND relkind = 'S'"
    ).to_i.positive?
  end

  def compute_totals!
    self.subtotal_cents = order_items.sum { |item| item.price_cents.to_i * item.quantity.to_i }

    if Setting.enabled?("commissions_enabled")
      self.commission_percent = BigDecimal(Setting.get("commission_percent", 0).to_s)
      self.commission_cents = (subtotal_cents * commission_percent / 100).round
    else
      self.commission_percent = 0
      self.commission_cents = 0
    end

    self.total_cents = subtotal_cents + shipping_cents.to_i
    save!
    self
  end

  def net_to_seller_cents
    subtotal_cents - commission_cents
  end

  def guest?
    buyer_id.nil?
  end

  def cancellable?
    pending_payment?
  end

  def paid?
    paid_at.present?
  end

  # Idempotent: Stripe and admin tools may deliver the same event twice.
  def mark_paid!(reference: nil, provider: nil)
    return true if paid?
    return false if cancelled?

    update!(
      status: :paid,
      paid_at: Time.current,
      payment_reference: reference.presence || payment_reference,
      payment_provider: provider.presence || payment_provider
    )
    true
  end

  def cancel_unpaid!(reason: nil)
    cancelled = false
    transaction do
      lock!
      next unless cancellable?

      restore_stock_locked!
      update!(
        status: :cancelled,
        cancelled_at: Time.current,
        cancel_reason: reason
      )
      cancelled = true
    end
    cancelled
  end

  # Puts stock back once and relists listings that this order sold out.
  def restore_stock!
    transaction do
      lock!
      restore_stock_locked!
    end
  end

  def timeline
    [
      { key: "placed", at: created_at, done: true },
      { key: "paid", at: paid_at, done: paid? || shipped? || delivered? || completed? },
      { key: "shipped", at: shipped_at, done: shipped? || delivered? || completed? },
      { key: "delivered", at: delivered_at, done: delivered? || completed? },
      { key: "completed", at: completed_at, done: completed? }
    ]
  end

  def to_param
    number
  end

  private

  def restore_stock_locked!
    return if stock_restored_at.present?

    order_items.includes(:listing).each do |item|
      listing = item.listing
      next if listing.blank?

      listing.with_lock do
        listing.update_columns(
          quantity: listing.quantity.to_i + item.quantity.to_i,
          status: listing.sold? ? Listing.statuses[:published] : listing.status,
          updated_at: Time.current
        )
      end
    end

    update_columns(stock_restored_at: Time.current, updated_at: Time.current)
  end

  def assign_number
    return if number.present?

    self.number = format("%s-%d-%06d", NUMBER_PREFIX, Time.current.year, self.class.next_number)
  end
end
