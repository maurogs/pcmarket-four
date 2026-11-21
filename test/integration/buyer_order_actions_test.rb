require "test_helper"

class BuyerOrderActionsTest < ActionDispatch::IntegrationTest
  setup do
    Setting.set("inspection_window_days", 2)
    Setting.set("reviews_enabled", true)
    Setting.set("blocked_words", "")
    sign_in users(:buyer)
  end

  test "buyer confirms receipt of a shipped order" do
    order = create_order(status: :shipped)

    get order_path(order, locale: :es)
    assert_response :success
    assert_select "form[action='#{order_delivery_confirmation_path(order, locale: :es)}']"

    post order_delivery_confirmation_path(order, locale: :es)

    assert_redirected_to order_path(order, locale: :es)
    assert order.reload.delivered?
    assert_equal "delivered", order.order_events.chronological.last.kind
  end

  test "buyer cannot confirm an order that has not shipped" do
    order = create_order(status: :paid)

    post order_delivery_confirmation_path(order, locale: :es)

    assert_response :redirect
    assert order.reload.paid?
  end

  test "buyer opens a dispute with a reason and details inside the window" do
    order = create_order(status: :shipped)
    order.update_columns(shipped_at: 1.day.ago)

    get new_order_dispute_path(order, locale: :es)
    assert_response :success
    assert_select "input[type=radio][name='dispute[reason]']", count: Order::DISPUTE_REASONS.size

    post order_dispute_path(order, locale: :es),
         params: { dispute: { reason: "damaged", details: "The screen is cracked." } }

    assert_redirected_to order_path(order, locale: :es)
    order.reload
    assert order.disputed?
    event = order.order_events.chronological.last
    assert_equal "damaged", event.data["reason"]
    assert_equal "The screen is cracked.", event.data["details"]
  end

  test "dispute window closes after the inspection period" do
    order = create_order(status: :shipped)
    order.update_columns(shipped_at: 5.days.ago)

    get new_order_dispute_path(order, locale: :es)
    assert_response :redirect

    post order_dispute_path(order, locale: :es), params: { dispute: { reason: "damaged" } }
    assert_response :redirect
    assert order.reload.shipped?
  end

  test "buyer leaves one review on a completed order" do
    order = create_order(status: :completed)

    get new_order_review_path(order, locale: :es)
    assert_response :success
    assert_select "input[type=radio][name='review[rating]']", count: 5

    post order_review_path(order, locale: :es),
         params: { review: { rating: 5, body: "Great seller, fast shipping and well packed." } }

    assert_redirected_to order_path(order, locale: :es)
    review = order.reload.review
    assert_equal 5, review.rating
    assert_equal users(:buyer), review.reviewer

    get new_order_review_path(order, locale: :es)
    assert_response :redirect
  end

  test "reviews are rejected for non-buyers, unpaid orders and duplicates" do
    paid = create_order(status: :paid)
    get new_order_review_path(paid, locale: :es)
    assert_response :redirect

    other = create_order(status: :completed, buyer: users(:seller))
    get new_order_review_path(other, locale: :es)
    assert_response :not_found

    reviewed = create_order(status: :completed)
    Review.create!(order: reviewed, reviewer: users(:buyer), store: reviewed.store,
                   rating: 4, body: "Good experience overall, would buy again from them.")
    get new_order_review_path(reviewed, locale: :es)
    assert_response :redirect
  end

  test "review bodies are rejected when they contain blocked words" do
    Setting.set("blocked_words", "scam, awful")
    order = create_order(status: :completed)

    post order_review_path(order, locale: :es),
         params: { review: { rating: 1, body: "This seller is a scam and awful to deal with." } }

    assert_response :unprocessable_entity
    assert_nil order.reload.review
  end

  test "review forms and sections are hidden when reviews are disabled" do
    Setting.set("reviews_enabled", false)
    order = create_order(status: :completed)

    get new_order_review_path(order, locale: :es)
    assert_redirected_to orders_path(locale: :es)

    get order_path(order, locale: :es)
    assert_response :success
    assert_select "a[href='#{new_order_review_path(order, locale: :es)}']", count: 0
  end
end
