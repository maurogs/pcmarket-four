class Order < ApplicationRecord
  NUMBER_PREFIX = "PCM"
  NUMBER_SEQUENCE = "order_number_seq".freeze
  FILTERS = {
    "all" => nil,
    "to_pay" => %w[pending_payment],
    "in_progress" => %w[paid shipped delivered disputed],
    "completed" => %w[completed],
    "cancelled" => %w[cancelled refunded]
  }.freeze

  SELLER_FILTERS = {
    "to_ship" => %w[paid],
    "awaiting_payment" => %w[pending_payment],
    "shipped" => %w[shipped],
    "completed" => %w[delivered completed],
    "cancelled" => %w[cancelled refunded],
    "disputes" => %w[disputed]
  }.freeze

  CARRIERS = %w[correos correos_express seur mrw gls dhl ups nacex inpost other].freeze
  DISPUTE_REASONS = %w[not_received not_as_described damaged counterfeit other].freeze
  DISPUTE_PHOTO_LIMIT = 5

  CARRIER_TRACKING_URLS = {
    "correos" => "https://www.correos.es/es/es/herramientas/localizador/envios/resultados?numero=%{tracking}",
    "correos_express" => "https://www.correosexpress.com/web/correosexpress/seguimiento-envios?n=%{tracking}",
    "seur" => "https://www.seur.com/livetracking/?segOnlineIdentificador=%{tracking}",
    "mrw" => "https://www.mrw.es/seguimiento_envios/MRW_resultados_consultas.asp?modo=nacional&envio=%{tracking}",
    "gls" => "https://gls-group.eu/ES/es/seguimiento-de-paquetes?match=%{tracking}",
    "dhl" => "https://www.dhl.com/es-es/home/tracking.html?tracking-id=%{tracking}",
    "ups" => "https://www.ups.com/track?tracknum=%{tracking}",
    "nacex" => "https://www.nacex.es/seguimiento.do?n=%{tracking}",
    "inpost" => "https://inpost.es/en/tracking/%{tracking}"
  }.freeze

  belongs_to :buyer, class_name: "User", optional: true, inverse_of: :orders_as_buyer
  belongs_to :seller, class_name: "User", inverse_of: :orders_as_seller
  belongs_to :store, optional: true, inverse_of: :orders

  has_many :order_items, dependent: :destroy, inverse_of: :order
  has_many :listings, through: :order_items
  has_many :order_events, dependent: :destroy, inverse_of: :order
  has_one :review, dependent: :destroy, inverse_of: :order

  has_many_attached :dispute_photos

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
  after_create :record_placed_event

  validates :number, presence: true, uniqueness: true
  validates :subtotal_cents, :shipping_cents, :commission_cents, :total_cents,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :buyer_email, presence: true, if: :guest?
  validates :buyer_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :payment_method, inclusion: { in: %w[bank_transfer cash_on_pickup stripe] },
                             allow_nil: true
  validate :dispute_photo_count

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

  def self.seller_orders(user, filter: "to_ship", query: nil)
    statuses = SELLER_FILTERS[filter.to_s]
    scope = where(seller_id: user.id)
    scope = scope.where(status: statuses) if statuses

    if query.present?
      pattern = "%#{sanitize_sql_like(query.to_s.strip)}%"
      scope = scope.left_joins(:order_items)
                   .where("orders.number ILIKE :q OR order_items.title_snapshot ILIKE :q", q: pattern)
                   .distinct
    end

    scope.includes(:buyer, :store, order_items: { listing: { images_attachments: :blob } })
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

  def inspection_window_days
    [ Setting.get("inspection_window_days", 2).to_i, 1 ].max
  end

  def inspection_window_end_at
    reference = delivered_at || shipped_at
    reference && reference + inspection_window_days.days
  end

  def inspection_window_open?
    finish = inspection_window_end_at
    finish.present? && Time.current <= finish
  end

  def buyer_details_visible?
    paid_at.present? || shipped_at.present? || delivered_at.present? ||
      completed_at.present? || disputed_at.present?
  end

  def tracking_url
    return nil if carrier.blank? || tracking_number.blank?

    template = CARRIER_TRACKING_URLS[carrier]
    return nil if template.blank?

    format(template, tracking: ERB::Util.url_encode(tracking_number))
  end

  # Idempotent: Stripe and admin tools may deliver the same event twice.
  def mark_paid!(actor = nil, reference: nil, provider: nil)
    return true if paid?
    return false unless pending_payment?
    return false unless paid_actor_allowed?(actor)

    applied = false
    transaction do
      lock!
      next unless pending_payment?

      update!(
        status: :paid,
        paid_at: Time.current,
        payment_reference: reference.presence || payment_reference,
        payment_provider: provider.presence || payment_provider
      )
      record_event!(:paid, actor: actor, data: { provider: payment_provider, reference: payment_reference }.compact)
      applied = true
    end
    notify_lifecycle(:paid, actor) if applied
    applied
  end

  def ship!(actor, carrier:, tracking_number: nil)
    carrier = carrier.to_s
    tracking_number = tracking_number.to_s.strip
    return false unless actor.present? && actor.id == seller_id
    return false unless paid?
    return false unless CARRIERS.include?(carrier)
    return false if carrier != "other" && tracking_number.blank?

    applied = false
    transaction do
      lock!
      next unless paid?

      update!(status: :shipped, shipped_at: Time.current, carrier: carrier,
              tracking_number: tracking_number.presence)
      record_event!(:shipped, actor: actor,
                    data: { carrier: carrier, tracking_number: tracking_number.presence }.compact)
      applied = true
    end
    notify_lifecycle(:shipped, actor) if applied
    applied
  end

  def mark_ready_for_pickup!(actor)
    return false unless actor.present? && actor.id == seller_id
    return false unless paid? && local_pickup?

    applied = false
    transaction do
      lock!
      next unless paid? && local_pickup?

      update!(status: :shipped, shipped_at: Time.current)
      record_event!(:ready_for_pickup, actor: actor)
      applied = true
    end
    notify_lifecycle(:ready_for_pickup, actor) if applied
    applied
  end

  def confirm_delivery!(actor = nil, automatic: false)
    return false unless shipped?
    return false unless actor.nil? || automatic || actor.admin? || actor.id == buyer_id

    applied = false
    transaction do
      lock!
      next unless shipped?

      update!(status: :delivered, delivered_at: Time.current)
      record_event!(:delivered, actor: actor, data: { automatic: automatic }.compact)
      applied = true
    end
    notify_lifecycle(:delivered, actor) if applied
    applied
  end

  def complete!(actor = nil, force: false)
    return false unless delivered?
    return false unless force || inspection_window_elapsed?

    applied = false
    transaction do
      lock!
      next unless delivered?

      update!(status: :completed, completed_at: Time.current)
      record_event!(:completed, actor: actor)
      store&.increment!(:sales_count)
      applied = true
    end
    notify_lifecycle(:completed, actor) if applied
    applied
  end

  def cancel!(actor, reason, refund_required: nil)
    return false unless cancellable_by?(actor)

    was_paid = paid?
    refund = refund_required.nil? ? was_paid : refund_required
    applied = false

    transaction do
      lock!
      next unless cancellable_by?(actor)

      restore_stock_locked!
      update!(
        status: :cancelled,
        cancelled_at: Time.current,
        cancel_reason: reason.to_s,
        refund_required: ActiveModel::Type::Boolean.new.cast(refund) == true
      )
      record_event!(:cancelled, actor: actor,
                    data: { reason: reason.to_s, refund_required: refund }.compact)
      applied = true
    end
    notify_lifecycle(:cancelled, actor) if applied
    applied
  end

  def cancel_unpaid!(reason: nil)
    cancel!(nil, reason.presence || "payment_expired")
  end

  def open_dispute!(actor, reason, details = nil)
    return false unless actor.present? && actor.id == buyer_id
    return false unless %w[shipped delivered].include?(status)
    return false unless DISPUTE_REASONS.include?(reason.to_s)
    return false unless inspection_window_open?

    applied = false
    transaction do
      lock!
      next unless %w[shipped delivered].include?(status)
      next unless inspection_window_open?

      update!(status: :disputed, disputed_at: Time.current)
      record_event!(:dispute_opened, actor: actor,
                    data: { reason: reason.to_s, details: details.to_s.presence }.compact)
      applied = true
    end
    notify_lifecycle(:dispute_opened, actor) if applied
    applied
  end

  def resolve_dispute!(actor, outcome:)
    return false unless actor.present? && actor.admin?
    return false unless disputed?
    return false unless %w[refund release].include?(outcome.to_s)

    applied = false
    transaction do
      lock!
      next unless disputed?

      if outcome.to_s == "refund"
        update!(status: :refunded, refunded_at: Time.current, refund_required: false)
      else
        update!(status: :completed, completed_at: Time.current)
        store&.increment!(:sales_count)
      end
      record_event!(:dispute_resolved, actor: actor, data: { outcome: outcome.to_s })
      applied = true
    end
    notify_lifecycle(:dispute_resolved, actor) if applied
    applied
  end

  def refund!(actor)
    return false unless actor.present? && actor.admin?
    return false unless %w[paid shipped delivered completed disputed].include?(status)

    applied = false
    transaction do
      lock!
      next unless %w[paid shipped delivered completed disputed].include?(status)

      restore_stock_locked! if shipped_at.blank?
      update!(status: :refunded, refunded_at: Time.current, refund_required: false)
      record_event!(:refunded, actor: actor)
      applied = true
    end
    notify_lifecycle(:refunded, actor) if applied
    applied
  end

  def flag_late_shipment!
    return false unless paid?
    return false if shipped_at.present? || late_shipment_notified_at.present?

    applied = false
    transaction do
      lock!
      next if shipped_at.present? || late_shipment_notified_at.present?

      update!(late_shipment_notified_at: Time.current)
      record_event!(:late_shipment_reminder, actor: nil)
      applied = true
    end
    notify_lifecycle(:late_shipment_reminder, nil) if applied
    applied
  end

  def inspection_window_elapsed?
    finish = inspection_window_end_at
    finish.present? && Time.current > finish
  end

  # Public stock restore used by the expiry sweep and refunds.
  def restore_stock!
    transaction do
      lock!
      restore_stock_locked!
    end
  end

  def timeline
    events = order_events.chronological.to_a
    return legacy_timeline if events.empty?

    events.map { |event| { key: event.kind, at: event.created_at, event: event } }
  end

  def to_param
    number
  end

  private

  def paid_actor_allowed?(actor)
    return true if actor.nil? || actor.admin?

    actor.id == seller_id && payment_method == "cash_on_pickup"
  end

  def cancellable_by?(actor)
    case status
    when "pending_payment"
      actor.nil? || actor.admin? || actor.id == buyer_id || actor.id == seller_id
    when "paid"
      actor.nil? || actor.admin? || actor.id == seller_id
    else
      false
    end
  end

  def record_event!(kind, actor: nil, data: {})
    order_events.create!(kind: kind.to_s, actor: actor, data: data)
  end

  def record_placed_event
    order_events.create!(kind: "placed")
  rescue ActiveRecord::RecordInvalid
    nil
  end

  def notify_lifecycle(kind, actor)
    OrderNotifier.call(self, kind, actor: actor)
  end

  def legacy_timeline
    [
      { key: "placed", at: created_at, event: nil },
      { key: "paid", at: paid_at, event: nil },
      { key: "shipped", at: shipped_at, event: nil },
      { key: "delivered", at: delivered_at, event: nil },
      { key: "completed", at: completed_at, event: nil }
    ].select { |step| step[:at].present? }
  end

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

  def dispute_photo_count
    return unless dispute_photos.attached?

    errors.add(:dispute_photos, :too_many) if dispute_photos.size > DISPUTE_PHOTO_LIMIT
  end

  def assign_number
    return if number.present?

    self.number = format("%s-%d-%06d", NUMBER_PREFIX, Time.current.year, self.class.next_number)
  end
end
