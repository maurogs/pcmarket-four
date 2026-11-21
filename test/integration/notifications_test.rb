require "test_helper"

class NotificationsTest < ActionDispatch::IntegrationTest
  setup do
    @buyer = users(:buyer)
    @order = create_order(status: :paid)
    @notification = Notifier.call(
      @buyer, "order_paid",
      params: { order_id: @order.id, number: @order.number },
      url: order_path(@order, locale: :es)
    )
    sign_in @buyer
  end

  test "notifications page lists unread notifications first" do
    old = @buyer.notifications.create!(kind: "order_shipped", params: { number: @order.number },
                                       read_at: 1.day.ago, created_at: 2.days.ago)

    get notifications_path(locale: :es)

    assert_response :success
    assert_match I18n.t("notifications.kinds.order_paid", number: @order.number), response.body
    assert_match I18n.t("notifications.kinds.order_shipped", number: @order.number), response.body
    unread_position = response.body.index(I18n.t("notifications.kinds.order_paid", number: @order.number))
    read_position = response.body.index(I18n.t("notifications.kinds.order_shipped", number: @order.number))
    assert_operator unread_position, :<, read_position
  end

  test "mark all read clears the unread count" do
    post notifications_read_all_path(locale: :es)

    assert_redirected_to notifications_path(locale: :es)
    assert_equal 0, @buyer.notifications.unread.count
  end

  test "header menu frame returns the latest notifications" do
    get notifications_path(locale: :es, menu: 1)

    assert_response :success
    assert_match I18n.t("notifications.kinds.order_paid", number: @order.number), response.body
  end

  test "opening a notification marks it read and redirects to its target" do
    patch notification_path(@notification, locale: :es)

    assert_redirected_to order_path(@order, locale: :es)
    assert @notification.reload.read?
  end

  test "a new notification broadcasts a badge update to the user" do
    assert_turbo_stream_broadcasts [ @buyer, :notifications ] do
      @buyer.notifications.create!(kind: "order_delivered", params: { number: @order.number })
    end
  end
end
