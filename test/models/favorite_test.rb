require "test_helper"

class FavoriteTest < ActiveSupport::TestCase
  test "increments the listing favorites counter cache" do
    listing = listings(:published_gpu)

    assert_difference -> { listing.reload.favorites_count }, 1 do
      Favorite.create!(user: users(:moderator), listing: listing)
    end
  end

  test "a user can only favourite a listing once" do
    listing = listings(:published_gpu)
    Favorite.create!(user: users(:moderator), listing: listing)

    duplicate = Favorite.new(user: users(:moderator), listing: listing)
    assert_not duplicate.valid?
    assert duplicate.errors[:listing_id].any?
  end
end
