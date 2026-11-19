require "test_helper"

# Review's rating recalculation runs in after_commit, which never fires under
# transactional fixtures — this test commits for real and cleans up by hand
# (reviews is not a fixture table, so fixtures reload would not clear it).
class Stores::RatingRecalculatorTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @store = stores(:confirmed_store)
    @author = create_user("recalculator")
  end

  teardown do
    Review.delete_all
  end

  test "average and count are recomputed from published reviews" do
    create_review(rating: 4)
    create_review(rating: 5, author: create_user("recalculator2"))

    @store.reload

    assert_equal 4.5, @store.rating_avg
    assert_equal 2, @store.ratings_count
  end

  test "average is rounded to two decimals" do
    create_review(rating: 1)
    create_review(rating: 1)
    create_review(rating: 2)

    assert_equal BigDecimal("1.33"), @store.reload.rating_avg
    assert_equal 3, @store.ratings_count
  end

  test "hiding a review recomputes the average" do
    good = create_review(rating: 5)
    create_review(rating: 1)

    good.update!(status: :hidden)

    assert_equal 1.0, @store.reload.rating_avg
    assert_equal 1, @store.ratings_count
  end

  test "destroying the last review resets the rating" do
    review = create_review(rating: 4)

    review.destroy!

    assert_equal 0.0, @store.reload.rating_avg
    assert_equal 0, @store.ratings_count
  end

  private

  def create_review(**overrides)
    Review.create!({ store: @store, author: @author, rating: 5 }.merge(overrides))
  end

  def create_user(name)
    User.create!(email: "#{name}@example.com", username: name,
                 password: "password123", confirmed_at: Time.current)
  end
end
