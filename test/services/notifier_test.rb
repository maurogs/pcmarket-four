require "test_helper"

class NotifierTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    @order = create_order(status: :paid)
    @buyer = users(:buyer)
    @buyer.update!(notification_preferences: { "email_order_updates" => true })
  end

  test "creates an in-app notification and enqueues the email" do
    assert_difference -> { @buyer.notifications.count }, 1 do
      assert_enqueued_emails 1 do
        Notifier.call(@buyer, "order_paid",
                      params: { order_id: @order.id, number: @order.number },
                      url: "/es/orders/#{@order.number}")
      end
    end

    notification = @buyer.notifications.order(:created_at).last
    assert_equal "order_paid", notification.kind
    assert_equal @order.number, notification.params["number"]
    assert notification.url.present?
  end

  test "respects the order update email preference" do
    @buyer.update!(notification_preferences: { "email_order_updates" => false })

    assert_no_enqueued_emails do
      assert_difference -> { @buyer.notifications.count }, 1 do
        Notifier.call(@buyer, "order_paid", params: { order_id: @order.id, number: @order.number })
      end
    end
  end
end
