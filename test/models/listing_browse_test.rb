require "test_helper"

class ListingBrowseTest < ActiveSupport::TestCase
  include CatalogHelpers

  setup do
    @catalog = create_browse_catalog
    @listing = @catalog[:gpu_rtx]
  end

  test "visible_to_public? follows status and vacation mode" do
    assert_predicate @listing, :visible_to_public?

    stores(:confirmed_store).update!(vacation_mode: true)
    refute_predicate @listing.reload, :visible_to_public?
  end

  test "viewable_by? grants owners and admins, denies strangers" do
    hidden = @catalog[:gpu_pending]

    refute hidden.viewable_by?(nil)
    assert hidden.viewable_by?(users(:confirmed))

    admin = User.create!(email: "view-admin@example.com", username: "viewadmin",
                         password: "password123", role: :admin)
    assert hidden.viewable_by?(admin)
    refute hidden.viewable_by?(users(:pending))
  end

  test "estimated arrival spans preparation plus transit" do
    assert_equal @listing.ships_within_days.days.from_now.to_date, @listing.estimated_arrival_from
    assert_operator (@listing.estimated_arrival_to - @listing.estimated_arrival_from), :>=, 1
  end

  test "similar_to stays in category and price band, excluding self" do
    similar = Listing.similar_to(@listing)

    assert_includes similar, @catalog[:gpu_rx]
    refute_includes similar, @listing
    refute_includes similar, @catalog[:cpu_i5]
    refute_includes similar, @catalog[:gpu_pending]
  end

  test "more_from_store excludes the current listing" do
    others = Listing.more_from_store(@listing)

    assert_includes others, @catalog[:gpu_rx]
    refute_includes others, @listing
  end

  test "ancestors walks from the root down to the parent" do
    assert_equal [ categories(:components) ], categories(:gpus).ancestors
    assert_empty categories(:gaming_pcs).ancestors
  end

  test "find_by_param resolves historical slugs" do
    listing = create_listing(title: "MSI Ventus RTX 3060 Ghost")
    old_slug = listing.slug
    listing.update!(title: "MSI Ventus RTX 3060 RTX")

    assert_equal listing, Listing.find_by_param(old_slug)
  end
end
