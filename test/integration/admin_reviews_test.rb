require "test_helper"

class AdminReviewsTest < ActionDispatch::IntegrationTest
  setup do
    @review = reviews(:delivered_order_review)
    sign_in users(:admin)
  end

  test "index renders filters and review rows" do
    get admin_reviews_path(locale: :es)

    assert_response :success
    assert_select "#admin-filter-rating"
    assert_select "#admin-filter-has_reply"
    assert_match @review.store.name, response.body
  end

  test "show renders the review and its order" do
    get admin_review_path(@review, locale: :es)

    assert_response :success
    assert_match @review.body, response.body
    assert_match @review.order.number, response.body
  end

  test "unpublishing a review recalculates the store rating" do
    store = @review.store

    patch admin_review_path(@review, locale: :es), params: { review: { published: false } }

    assert_equal false, @review.reload.published
    store.reload
    assert_equal 0, store.reviews_count
    assert_equal 0, store.rating_avg.to_i
    assert AdminAuditLog.exists?(auditable: @review, action: "review.updated")
  end

  test "toggling reply visibility hides the seller reply" do
    @review.update!(seller_reply: "Gracias por tu compra.")

    patch admin_review_path(@review, locale: :es), params: { review: { seller_reply_visible: false } }

    assert_equal false, @review.reload.seller_reply_visible
  end

  test "deleting a review is admin only" do
    sign_out users(:admin)
    sign_in users(:moderator)

    assert_no_difference -> { Review.count } do
      delete admin_review_path(@review, locale: :es)
    end
    assert_redirected_to root_path

    sign_out users(:moderator)
    sign_in users(:admin)

    assert_difference -> { Review.count }, -1 do
      delete admin_review_path(@review, locale: :es)
    end
  end
end
