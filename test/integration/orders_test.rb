require "test_helper"

class OrdersTest < ActionDispatch::IntegrationTest
  test "buyer sees only their own orders and can filter and search" do
    sign_in users(:buyer)

    get orders_path(locale: :es)
    assert_response :success
    assert_match orders(:delivered_order).number, response.body
    assert_no_match orders(:second_review_order).number, response.body

    get orders_path(locale: :es, filter: "to_pay")
    assert_response :success
    assert_match orders(:pending_order).number, response.body

    get orders_path(locale: :es, q: "RTX 4070")
    assert_response :success
    assert_match orders(:delivered_order).number, response.body
  end

  test "another user cannot open a buyer's order" do
    sign_in users(:seller)

    get order_path(orders(:delivered_order), locale: :es)

    assert_response :redirect
  end

  test "buyer can cancel an unpaid order and stock returns" do
    order = orders(:pending_order)
    listing = listings(:published_gpu)
    order.order_items.create!(listing: listing, title_snapshot: listing.title,
                              price_cents: listing.price_cents, quantity: 1)
    listing.update_columns(quantity: 0, status: Listing.statuses[:sold], updated_at: Time.current)
    sign_in users(:buyer)

    post order_cancellation_path(order, locale: :es)

    assert_redirected_to order_path(order, locale: :es)
    assert order.reload.cancelled?
    assert_equal "buyer_cancelled", order.cancel_reason
    assert listing.reload.published?
    assert_equal 1, listing.quantity
  end

  test "guest with a valid token sees the order but cannot cancel it" do
    order = orders(:pending_order)
    order.update_columns(buyer_id: nil, guest_access_token: "guest-access-xyz")

    get order_path(order, locale: :es, token: "guest-access-xyz")
    assert_response :success
    assert_select "form[action='#{order_cancellation_path(order, locale: :es)}']", count: 0
  end
end
