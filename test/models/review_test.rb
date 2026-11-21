require "test_helper"

class ReviewTest < ActiveSupport::TestCase
  test "recalculates the store rating after commit" do
    store = stores(:seller_store)
    review = Review.new(
      order: orders(:second_review_order),
      reviewer: users(:buyer),
      store: store,
      rating: 3,
      body: "Todo correcto, aunque el envío tardó un poco más de lo esperado."
    )

    assert review.save!
    review.run_callbacks(:commit)

    store.reload
    assert_equal 2, store.reviews_count
    assert_in_delta 4.0, store.rating_avg.to_f, 0.01
  end

  test "recalculates on rating update" do
    review = reviews(:delivered_order_review)
    review.update!(rating: 1)
    review.run_callbacks(:commit)

    store = stores(:seller_store).reload
    assert_equal 1, store.reviews_count
    assert_in_delta 1.0, store.rating_avg.to_f, 0.01
  end

  test "rating must be between 1 and 5" do
    review = Review.new(
      order: orders(:second_review_order),
      reviewer: users(:buyer),
      store: stores(:seller_store),
      rating: 6
    )

    assert_not review.valid?
    assert review.errors[:rating].any?
  end
end
