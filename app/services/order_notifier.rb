class OrderNotifier
  def self.call(order, kind, actor: nil, data: {})
    new(order, kind, actor: actor, data: data).call
  end

  def initialize(order, kind, actor: nil, data: {})
    @order = order
    @kind = kind.to_s
    @actor = actor
    @data = data.to_h.symbolize_keys
  end

  def call
    case kind
    when "paid"
      notify_buyer("order_paid")
      notify_seller("order_paid_seller")
    when "shipped"
      notify_buyer("order_shipped")
    when "ready_for_pickup"
      notify_buyer("order_ready_for_pickup")
    when "delivered"
      notify_buyer("order_delivered")
    when "completed"
      notify_buyer("order_completed")
    when "cancelled"
      notify_buyer("order_cancelled")
      notify_seller("order_cancelled_seller")
    when "dispute_opened"
      notify_seller("order_dispute_opened")
      notify_support
    when "dispute_resolved"
      notify_dispute_resolution
    when "refunded"
      notify_buyer("order_refunded")
      notify_seller("order_refunded")
    when "late_shipment_reminder"
      notify_seller("order_late_shipment")
    end
  end

  private

  attr_reader :order, :kind, :actor, :data

  def notify_buyer(notification_kind, extra: {})
    if order.buyer.present?
      Notifier.call(order.buyer, notification_kind,
                    params: notification_params.merge(extra), url: buyer_url)
    else
      deliver_guest_email(notification_kind)
    end
  end

  def notify_seller(notification_kind, extra: {})
    Notifier.call(order.seller, notification_kind,
                  params: notification_params.merge(extra), url: seller_url)
  end

  def notify_dispute_resolution
    resolution = {
      outcome: I18n.t("admin.disputes.outcomes.#{data[:outcome]}", default: data[:outcome].to_s),
      message: data[:message].to_s
    }
    notify_buyer("order_dispute_resolution", extra: resolution)
    notify_seller("order_dispute_resolution", extra: resolution)
    enqueue_resolution_emails
  end

  def enqueue_resolution_emails
    if order.buyer.nil? || order.buyer.notify_by_email?(Notifier::PREFERENCE_KEY)
      OrderMailer.dispute_resolved_buyer(
        order, message: data[:message].to_s, outcome: data[:outcome].to_s, locale: order.locale
      ).deliver_later
    end
    if order.seller.notify_by_email?(Notifier::PREFERENCE_KEY)
      OrderMailer.dispute_resolved_seller(
        order, message: data[:message].to_s, outcome: data[:outcome].to_s, locale: order.seller.locale
      ).deliver_later
    end
  end

  def notify_support
    OrderMailer.dispute_admin(
      order,
      to: Setting.get("support_email", "soporte@pcmarket.test"),
      locale: I18n.default_locale
    ).deliver_later
  end

  def deliver_guest_email(notification_kind)
    method = Notifier::EMAIL_METHODS[notification_kind]
    return if method.blank?

    OrderMailer.public_send(method, order, locale: order.locale).deliver_later
  end

  def notification_params
    {
      order_id: order.id,
      number: order.number,
      store: order.store&.name || order.seller.display_name
    }
  end

  def buyer_url
    Rails.application.routes.url_helpers.order_path(order, locale: order.locale)
  end

  def seller_url
    Rails.application.routes.url_helpers.seller_order_path(order, locale: order.locale)
  end
end
