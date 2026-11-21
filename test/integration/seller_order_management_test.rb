require "test_helper"

class SellerOrderManagementTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:seller)
    Setting.set("reviews_enabled", true)
  end

  test "seller sales tabs render counts and orders" do
    create_order(status: :paid)

    get seller_orders_path(locale: :es)
    assert_response :success
    assert_select "[role=tab]", count: Order::SELLER_FILTERS.size
    assert_match I18n.t("seller.orders.tabs.to_ship"), response.body
  end

  test "shipping requires a tracking number unless the carrier is other" do
    order = create_order(status: :paid)

    post seller_order_shipment_path(order, locale: :es),
         params: { order: { carrier: "seur", tracking_number: "" } }
    assert_redirected_to seller_order_path(order, locale: :es)
    assert order.reload.paid?

    post seller_order_shipment_path(order, locale: :es),
         params: { order: { carrier: "seur", tracking_number: "SE999" } }
    assert order.reload.shipped?
    assert_equal "SE999", order.tracking_number
  end

  test "buyer address is hidden before payment and shown once paid" do
    pending = create_order(ship_line1: "Secret Street 1", ship_city: "Barcelona",
                           ship_postal_code: "08001", ship_name: "Bruno Buyer")
    paid = create_order(status: :paid, ship_line1: "Visible Street 2", ship_city: "Madrid",
                        ship_postal_code: "28001", ship_name: "Bruno Buyer")

    get seller_order_path(pending, locale: :es)
    assert_response :success
    assert_no_match "Secret Street 1", response.body
    assert_match I18n.t("seller.orders.show.address_hidden"), response.body

    get seller_order_path(paid, locale: :es)
    assert_response :success
    assert_match "Visible Street 2", response.body
  end

  test "seller marks a local pickup order ready and a cash order paid" do
    pickup = create_order(status: :paid, fulfilment: :local_pickup)
    post seller_order_pickup_path(pickup, locale: :es)
    assert pickup.reload.shipped?

    cash = create_order(payment_method: "cash_on_pickup", fulfilment: :local_pickup)
    post seller_order_payment_path(cash, locale: :es)
    assert cash.reload.paid?
  end

  test "seller cancels a paid order with a reason and refund flag" do
    order = create_order(status: :paid)

    post seller_order_cancellation_path(order, locale: :es),
         params: { order: { reason: "Item is no longer available" } }

    order.reload
    assert order.cancelled?
    assert order.refund_required?
    assert_equal "Item is no longer available", order.cancel_reason
  end

  test "CSV export respects seller ownership" do
    own = create_order(status: :paid)
    other = create_order(status: :paid, seller: users(:moderator))

    post seller_order_exports_path(locale: :es), params: { filter: "to_ship" }

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_match own.number, response.body
    assert_no_match other.number, response.body
  end

  test "seller packing slip is printable and contains the shipping address" do
    order = create_order(status: :paid, ship_line1: "Calle Mayor 10", ship_city: "Madrid",
                         ship_postal_code: "28013", ship_name: "Bruno Buyer")

    get seller_order_packing_slip_path(order, locale: :es)

    assert_response :success
    assert_match I18n.t("seller.orders.packing_slip.packing_slip"), response.body
    assert_match "Calle Mayor 10", response.body
  end

  test "seller replies to a review once through the order page" do
    order = create_order(status: :completed)
    Review.create!(order: order, reviewer: users(:buyer), store: order.store, rating: 5,
                   body: "Fantastic experience, everything arrived on time.")

    post seller_review_replies_path(locale: :es), params: {
      review_id: order.reload.review.id,
      review: { seller_reply: "Thank you very much for your purchase!" }
    }

    assert_equal "Thank you very much for your purchase!", order.review.reload.seller_reply
  end
end
