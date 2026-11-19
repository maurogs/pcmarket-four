require "test_helper"

class ListingsControllerTest < ActionDispatch::IntegrationTest
  include CatalogHelpers

  setup do
    @catalog = create_browse_catalog
    @listing = @catalog[:gpu_rtx]
  end

  test "shows a published listing" do
    get listing_path(@listing, locale: "en")

    assert_response :success
    assert_select "h1", @listing.title
    assert_response_contains "Free shipping"
    assert_response_contains "-24%"
    assert_response_contains "Buyer Protection"
  end

  test "responds with the listing etag and honors If-None-Match" do
    get listing_path(@listing, locale: "en")
    etag = response.etag
    assert_not_nil etag

    get listing_path(@listing, locale: "en"), headers: { "If-None-Match" => etag }
    assert_response :not_modified
  end

  test "enqueues the views counter job once per page view" do
    assert_enqueued_jobs 1, only: Listings::IncrementViewsCountJob do
      get listing_path(@listing, locale: "en")
    end
    assert_response :success
  end

  test "hidden listings are 404 for anonymous visitors" do
    get listing_path(@catalog[:gpu_pending], locale: "en")

    assert_response :not_found
  end

  test "the owner can preview a hidden listing" do
    sign_in users(:confirmed)
    get listing_path(@catalog[:gpu_pending], locale: "en")

    assert_response :success
    assert_response_contains "previewing"
    assert_enqueued_jobs 0, only: Listings::IncrementViewsCountJob
  end

  test "admins can preview hidden listings" do
    admin = User.create!(
      email: "browse-admin@example.com", username: "browseadmin",
      password: "password123", confirmed_at: Time.current, role: :admin
    )
    sign_in admin
    get listing_path(@catalog[:gpu_pending], locale: "en")

    assert_response :success
  end

  test "old slugs redirect permanently to the canonical path" do
    listing = create_listing(title: "GeForce Old Slug Probe Listing")
    old_slug = listing.slug
    listing.update!(slug: "renamed-#{old_slug}")

    get listing_path(old_slug, locale: "en")

    assert_response :moved_permanently
    assert_redirected_to listing_path(listing.reload.slug, locale: "en")
  end

  test "similar listings and seller scrollers render" do
    get listing_path(@listing, locale: "en")

    assert_response_contains "Similar listings"
    assert_response_contains "More from this seller"
    assert_select "a", text: /AMD Radeon RX 6600 8GB/
  end

  test "unknown listings are 404" do
    get listing_path("no-such-listing", locale: "en")

    assert_response :not_found
  end

  private

  def assert_response_contains(text)
    assert_includes response.body, ERB::Util.html_escape(text)
  end
end
