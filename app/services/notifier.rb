class Notifier
  PREFERENCE_KEY = "email_order_updates".freeze

  EMAIL_METHODS = {
    "order_paid" => :paid_buyer,
    "order_paid_seller" => :paid_seller,
    "order_shipped" => :shipped_buyer,
    "order_ready_for_pickup" => :shipped_buyer,
    "order_delivered" => :delivered_buyer,
    "order_completed" => :completed_buyer,
    "order_cancelled" => :cancelled_buyer,
    "order_cancelled_seller" => :cancelled_seller,
    "order_dispute_opened" => :dispute_seller,
    "order_late_shipment" => :late_shipment_seller
  }.freeze

  class << self
    def call(user, kind, params: {}, url: nil)
      return nil if user.blank?

      notification = user.notifications.create!(kind: kind.to_s, params: params, url: url)
      enqueue_email(user, notification)
      notification
    end

    private

    def enqueue_email(user, notification)
      method = EMAIL_METHODS[notification.kind]
      return if method.blank?
      return unless user.notify_by_email?(PREFERENCE_KEY)

      order_id = notification.params["order_id"] || notification.params[:order_id]
      order = Order.find_by(id: order_id)
      return if order.blank?

      OrderMailer.public_send(method, order, locale: user.locale).deliver_later
    end
  end
end
