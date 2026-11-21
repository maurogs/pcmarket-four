require "test_helper"

class ListingSearchTest < ActiveSupport::TestCase
  setup do
    @category = categories(:graphics_cards)
  end

  def publish(attributes = {})
    listing = Listing.new({
      user: users(:seller),
      store: stores(:seller_store),
      category: @category,
      title: "Tarjeta gráfica de prueba #{SecureRandom.hex(3)}",
      description: "Descripción suficientemente larga para validar el anuncio de prueba.",
      price_cents: 20_000,
      condition: :used_like_new,
      status: :published,
      published_at: Time.current,
      quantity: 1,
      country_code: "ES",
      region: regions(:madrid),
      city: "Madrid",
      shipping_available: true,
      local_pickup: false,
      free_shipping: false,
      specs: { "cpu_brand" => "intel" }
    }.merge(attributes))
    listing.save!
    listing
  end

  def search(params = {}, category: nil, **kwargs)
    category ||= @category
    ListingSearch.new(params: params.merge(kwargs), category: category).result
  end

  test "returns visible listings in the category subtree" do
    result = search

    assert_includes result.listings, listings(:published_gpu)
    assert_not_includes result.listings, listings(:draft_gpu)
    assert_not_includes result.listings, listings(:suspended_owner_listing)
  end

  test "text search uses pg_search only when a query is present" do
    assert_equal [ listings(:published_gpu) ], search(q: "RTX").listings
    assert_equal search.listings, search(q: "   ").listings
  end

  test "converts euro price inputs to cents" do
    assert_includes search(min_price: "500").listings, listings(:published_gpu)
    assert_not_includes search(min_price: "600").listings, listings(:published_gpu)
    assert_includes search(max_price: "549").listings, listings(:published_gpu)
    assert_not_includes search(max_price: "548").listings, listings(:published_gpu)
  end

  test "understands European thousands and decimal separators" do
    assert_includes search(max_price: "2,500").listings, listings(:published_gpu)
    assert_empty search(max_price: "2,50").listings
  end

  test "ignores non numeric price inputs" do
    assert_includes search(min_price: "abc").listings, listings(:published_gpu)
  end

  test "filters by condition" do
    assert_includes search(condition: [ "used_like_new" ]).listings, listings(:published_gpu)
    assert_empty search(condition: [ "used_good" ]).listings
  end

  test "ORs values inside labels and tags, ANDs across filters" do
    listing = publish(labels: [ "deal" ], tags: [ "rgb" ])

    assert_includes search(labels: [ "rare", "deal" ]).listings, listing
    assert_not_includes search(labels: [ "rare" ]).listings, listing
    assert_includes search(tags: [ "wood", "rgb" ]).listings, listing
    assert_empty search(labels: [ "deal" ], tags: [ "wood" ]).listings
  end

  test "spec filters use jsonb containment and AND across keys" do
    intel = publish(specs: { "cpu_brand" => "intel" })
    amd = publish(specs: { "cpu_brand" => "amd" })

    assert_includes search(f: { "cpu_brand" => [ "intel" ] }).listings, intel
    assert_not_includes search(f: { "cpu_brand" => [ "intel" ] }).listings, amd

    cpus = categories(:cpus)
    eight = publish(category: cpus, specs: { "cpu_brand" => "amd", "vram" => "8" })
    sixteen = publish(category: cpus, specs: { "cpu_brand" => "amd", "vram" => "16" })

    result = search({ f: { "cpu_brand" => [ "amd" ], "vram" => [ "8" ] } }, category: cpus)
    assert_includes result.listings, eight
    assert_not_includes result.listings, sixteen
  end

  test "ignores filter keys that are not effective for the category" do
    baseline = search.total_count

    result = search(f: {
      "not_a_filter" => [ "x" ],
      "cpu_brand); DROP TABLE listings; --" => [ "intel" ]
    })

    assert_equal baseline, result.total_count
    assert Listing.table_exists?
  end

  test "filters by shipping, pickup, free shipping and sale" do
    assert_includes search(shipping: [ "ship" ]).listings, listings(:published_gpu)
    assert_includes search(shipping: [ "pickup" ]).listings, listings(:published_gpu)
    assert_empty search(free_shipping: "1").listings
    assert_includes search(on_sale: "1").listings, listings(:published_gpu)
    assert_includes search(deals: "1").listings, listings(:published_gpu)
  end

  test "filters by seller slug" do
    assert_includes search(seller: stores(:seller_store).slug).listings,
                    listings(:published_gpu)
    assert_empty search(seller: "unknown-store").listings
  end

  test "filters by region" do
    assert_includes search(region_id: [ regions(:madrid).id.to_s ]).listings,
                    listings(:published_gpu)
    assert_empty search(region_id: [ regions(:catalonia).id.to_s ]).listings
  end

  test "sorts by price and popularity" do
    cheap = publish(price_cents: 10_000, published_at: 1.day.ago, favorites_count: 1)
    expensive = publish(price_cents: 30_000, published_at: Time.current, favorites_count: 9)

    assert_operator search(sort: "price_asc").listings.index(cheap),
                    :<, search(sort: "price_asc").listings.index(expensive)
    assert_operator search(sort: "price_desc").listings.index(expensive),
                    :<, search(sort: "price_desc").listings.index(cheap)
    assert_equal expensive, search(sort: "popular").listings.first
  end

  test "best match defaults to newest order when there is no query" do
    newest = publish(price_cents: 15_000, published_at: Time.current)
    publish(price_cents: 16_000, published_at: 3.days.ago)

    result = search(sort: "best_match")
    assert_equal "best_match", result.sort
    assert_equal newest, result.listings.first
    assert_equal "best_match", search(q: "RTX").sort
  end

  test "clamps the page to the maximum allowed" do
    result = ListingSearch.new(params: { page: "9999" }, category: @category).result

    assert_operator result.pagy.page, :<=, ListingSearch::MAX_PAGE
    assert_equal 1, result.pagy.page
  end

  test "builds active filters with params that remove only the selected value" do
    result = search(q: "rtx", condition: [ "used_like_new", "used_good" ],
                    labels: [ "deal" ], f: { "cpu_brand" => [ "intel" ] },
                    min_price: "100", max_price: "900", shipping: [ "ship" ])

    labels = result.active_filters.map(&:label)
    assert_includes labels, I18n.t("search.chips.query", query: "rtx")
    assert labels.any? { |label| label.include?("Intel") }

    condition_chip = result.active_filters.find { |chip| chip.key == "condition" && chip.value == "used_good" }
    assert_equal [ "used_like_new" ], Array(condition_chip.remove_params["condition"])
    assert_equal "100", condition_chip.remove_params["min_price"]
    assert_not condition_chip.remove_params.key?("page")

    spec_chip = result.active_filters.find { |chip| chip.key == "spec_cpu_brand" }
    assert_not spec_chip.remove_params.key?("f")
  end

  test "computes facet counts with a single grouped query" do
    publish(specs: { "cpu_brand" => "amd" })

    counts = 0
    callback = lambda do |_name, _start, _finish, _id, payload|
      counts += 1 if payload[:sql].include?("jsonb_each_text")
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      facets = search.facets
      assert_equal 1, facets.dig("cpu_brand", "intel")
      assert_equal 1, facets.dig("cpu_brand", "amd")
    end

    assert_equal 1, counts
  end

  test "exposes condition counts" do
    counts = search.condition_counts

    assert_equal 1, counts["used_like_new"]
    assert_nil counts["used_good"]
  end
end
