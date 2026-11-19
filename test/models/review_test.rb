require "test_helper"

class ReviewTest < ActiveSupport::TestCase
  setup do
    @store = stores(:confirmed_store)
    @author = create_user("reviewer")
  end

  test "rating must be a whole number from 1 to 5" do
    [ 0, 6, 2.5, nil ].each do |rating|
      review = Review.new(store: @store, author: @author, rating: rating)

      assert_not review.valid?, "expected #{rating.inspect} to be invalid"
      assert_includes review.errors.attribute_names, :rating
    end

    [ 1, 5 ].each do |rating|
      assert Review.new(store: @store, author: @author, rating: rating).valid?
    end
  end

  test "title and body have length caps" do
    review = Review.new(store: @store, author: @author, rating: 5,
                        title: "t" * 121, body: "b" * 2001)

    assert_not review.valid?
    assert_includes review.errors.attribute_names, :title
    assert_includes review.errors.attribute_names, :body

    review.title = "t" * 120
    review.body = "b" * 2000

    assert review.valid?
  end

  test "authors can't review their own store" do
    review = Review.new(store: @store, author: users(:confirmed), rating: 5)

    assert_not review.valid?
    assert review.errors.of_kind?(:store, :reviewing_own_store)
  end

  test "listing is optional and reviews start published" do
    review = create_review(rating: 4)

    assert_nil review.listing_id
    assert_predicate review, :published?
    assert_not_predicate review, :verified_purchase?
  end

  test "published scope excludes hidden reviews" do
    hidden = create_review(rating: 2)
    create_review(rating: 5)
    hidden.update!(status: :hidden)

    assert_equal [ 5 ], Review.published.recent.map(&:rating)
  end

  test "recent orders newest first" do
    old = create_review(rating: 3)
    fresh = create_review(rating: 4)
    old.update_columns(created_at: 2.days.ago)

    assert_equal [ fresh.id, old.id ], Review.recent.ids
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
