require "test_helper"

class Listings::SearchTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
    @vacation_store = Stores::EnsureForUser.call(users(:pending))
    @vacation_store.update_column(:vacation_mode, true)

    @nvidia = publish(
      create_listing(
        title: "MSI RTX 4070 Gaming X Trio 12 GB", price_cents: 100_000,
        specs: { "gpu_chipset" => [ "nvidia" ], "cpu_brand" => [ "intel" ] },
        watchers_count: 5, condition: :used_good
      ),
      published_at: 3.days.ago
    )
    @amd = publish(
      create_listing(
        title: "Sapphire RX 6600 Pulse Graphics Card", price_cents: 20_000,
        specs: { "gpu_chipset" => [ "amd" ] }, watchers_count: 10
      ),
      published_at: 1.day.ago
    )
    @laptop = publish(
      create_listing(
        title: "Portátil Táctil Lenovo Yoga 14", category: categories(:gaming_pcs),
        price_cents: 70_000
      ),
      published_at: 2.days.ago
    )
    @hidden = [
      create_listing(title: "Draft Zotac RTX 3060", category: categories(:gpus)),
      create_listing(title: "Vacation Gigabyte RTX", store: @vacation_store, category: categories(:gpus))
    ]
    publish(@hidden.last)
  end

  def search(params = {})
    Listings::Search.call(params)
  end

  def ids(result)
    result.listings.map(&:id)
  end

  # --- Text search -------------------------------------------------------

  test "matches on title words" do
    assert_equal [ @nvidia.id ], ids(search(q: "rtx 4070"))
  end

  test "query without accents finds accented titles and vice versa" do
    assert_equal [ @laptop.id ], ids(search(q: "tactil"))
    assert_equal [ @laptop.id ], ids(search(q: "Táctil"))
  end

  test "searches the trigger-maintained index, not a live LIKE" do
    @nvidia.update_column(:title, "Renamed Sapphire Pulse Card")

    # The trigger recomputed `searchable` on the direct UPDATE too.
    assert_equal [ @nvidia.id ], ids(search(q: "renamed sapphire"))
  end

  test "drafts and stores on vacation are never returned" do
    result = search

    assert_not_includes ids(result), @hidden.first.id
    assert_not_includes ids(result), @hidden.last.id
    assert_not_includes ids(result), nil
  end

  # --- Filters -------------------------------------------------------------

  test "category filter includes descendants" do
    ids = ids(search(category: "components"))

    assert_includes ids, @nvidia.id
    assert_includes ids, @amd.id
    assert_not_includes ids, @laptop.id
  end

  test "spec filters OR within a key and AND across keys" do
    assert_equal 2, ids(search(specs: { "gpu_chipset" => %w[nvidia amd] })).size
    assert_equal [ @nvidia.id ], ids(search(specs: { "gpu_chipset" => [ "nvidia" ], "cpu_brand" => [ "intel" ] }))
    assert_empty ids(search(specs: { "gpu_chipset" => [ "amd" ], "cpu_brand" => [ "intel" ] }))
  end

  test "price range and condition" do
    assert_equal [ @amd.id, @laptop.id ].sort, ids(search(min_price: 10_000, max_price: 80_000)).sort
    assert_equal [ @nvidia.id ], ids(search(condition: "used_good"))
  end

  # --- Sorting and pagination ---------------------------------------------

  test "sorts by price, recency and watchers" do
    assert_equal [ @amd.id, @laptop.id, @nvidia.id ], ids(search(sort: "price_asc"))
    assert_equal [ @nvidia.id, @laptop.id, @amd.id ], ids(search(sort: "price_desc"))
    assert_equal [ @amd.id, @laptop.id, @nvidia.id ], ids(search(sort: "newest"))
    assert_equal [ @amd.id, @nvidia.id, @laptop.id ], ids(search(sort: "most_watched"))
  end

  test "featured listings jump the queue in best_match" do
    @laptop.update!(featured_until: 1.day.from_now)

    assert_equal @laptop.id, search(sort: "best_match").listings.first.id
  end

  test "pagination respects page and per_page" do
    first_page = search(sort: "price_asc", per_page: 1)
    second_page = search(sort: "price_asc", per_page: 1, page: 2)

    assert_equal [ @amd.id ], ids(first_page)
    assert_equal [ @laptop.id ], ids(second_page)
    assert_equal 3, first_page.pagy.count
    assert_equal 3, first_page.pagy.pages
  end

  # --- Facets --------------------------------------------------------------

  test "facet counts aggregate per option, honoring other filters" do
    facets = search(category: "gpus").facets

    assert_equal %w[cpu_brand gpu_chipset], facets.keys.sort
    assert_equal({ "nvidia" => 1, "amd" => 1 }, facets["gpu_chipset"])
    assert_equal({ "intel" => 1, "amd" => 0 }, facets["cpu_brand"])
  end

  test "facet counts exclude the filtered dimension itself" do
    facets = search(category: "gpus", specs: { "gpu_chipset" => [ "nvidia" ] }).facets

    assert_equal({ "nvidia" => 1, "amd" => 1 }, facets["gpu_chipset"])
    assert_equal({ "intel" => 1, "amd" => 0 }, facets["cpu_brand"])
  end

  test "no facets without a category" do
    assert_empty search(q: "rtx").facets
  end

  test "facet definitions hidden from the sidebar are skipped" do
    filter_definitions(:gpu_chipset).update!(show_in_sidebar: false)

    assert_equal %w[cpu_brand], search(category: "gpus").facets.keys
  end

  test "facets are cached and invalidated when listings change" do
    first = search(category: "gpus")
    assert first.facets.key?("gpu_chipset")

    # A new published listing bumps the data version → fresh counts.
    publish(create_listing(title: "Nvidia Quadro RTX 4500", specs: { "gpu_chipset" => [ "nvidia" ] }))
    second = search(category: "gpus")

    assert_equal 2, second.facets["gpu_chipset"]["nvidia"]
  end

  # --- Performance ----------------------------------------------------------

  test "results page without N+1 queries on store and images" do
    set_setting("listing_auto_approve", true)
    @nvidia.images.attach(io: File.open(image_file), filename: "card.png", content_type: "image/png")
    @amd.update!(images: [ Rack::Test::UploadedFile.new(image_file("1x1.jpg"), "image/jpeg") ])

    result = search(category: "components")
    listings = result.listings.to_a

    queries = count_queries do
      listings.each do |listing|
        listing.store.display_name
        listing.store.logo.attached?
        listing.images.to_a.compact_blank
      end
    end

    assert_equal 0, queries
  end

  private

  def count_queries
    count = 0
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      count += 1 unless %w[SCHEMA TRANSACTION].include?(payload[:name])
    end
    yield
    count
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end
