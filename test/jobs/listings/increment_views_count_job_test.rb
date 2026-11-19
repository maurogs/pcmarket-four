require "test_helper"

class IncrementViewsCountJobTest < ActiveJob::TestCase
  include CatalogHelpers

  setup { @listing = publish(create_listing(title: "Viewed Gigabyte RTX 4060 Gaming OC")) }

  test "increments views_count once per dedupe key" do
    job = Listings::IncrementViewsCountJob.new
    3.times { job.perform(@listing.id, "visitor-1") }

    assert_equal 1, @listing.reload.views_count
  end

  test "different visitors count separately" do
    job = Listings::IncrementViewsCountJob.new
    job.perform(@listing.id, "visitor-1")
    job.perform(@listing.id, "visitor-2")

    assert_equal 2, @listing.reload.views_count
  end
end
