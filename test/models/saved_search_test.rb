require "test_helper"

class SavedSearchTest < ActiveSupport::TestCase
  test "matches a visible listing that satisfies every criterion" do
    assert saved_searches(:buyer_gpu_search).matches?(listings(:published_gpu))
  end

  test "does not match listings that are not visible" do
    assert_not saved_searches(:buyer_gpu_search).matches?(listings(:draft_gpu))
    assert_not saved_searches(:buyer_gpu_search).matches?(listings(:suspended_owner_listing))
  end

  test "does not match when a spec filter is missing" do
    search = saved_searches(:buyer_gpu_search)
    listing = listings(:published_gpu).dup
    listing.slug = "duplicate-gpu"
    listing.original_price_cents = nil
    listing.specs = { "cpu_brand" => "amd" }
    listing.save!

    assert_not search.matches?(listing)
  end

  test "respects the price range" do
    search = saved_searches(:buyer_gpu_search)
    listing = listings(:published_gpu).dup
    listing.slug = "expensive-gpu"
    listing.original_price_cents = nil
    listing.price_cents = 90_000
    listing.save!

    assert_not search.matches?(listing)
  end
end
