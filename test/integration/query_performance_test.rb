require "test_helper"

class QueryPerformanceTest < ActionDispatch::IntegrationTest
  setup do
    @original_cache = Rails.cache
    @original_perform_caching = ActionController::Base.perform_caching
    Rails.cache = ActiveSupport::Cache::NullStore.new
    ActionController::Base.perform_caching = false
    Setting.set("max_active_listings_per_user", 1_000)

    @listings = create_demo_like_listings(50)
    @listing = @listings.first
    prepare_card_variants
  end

  teardown do
    Rails.cache = @original_cache
    ActionController::Base.perform_caching = @original_perform_caching
  end

  test "home page renders 50 listings with fewer than 40 SQL queries" do
    queries = capture_queries { get "/es" }

    assert_response :success
    assert_select "article", minimum: 10
    warn "QUERY COUNT home=#{queries.size}" if ENV["PRINT_QUERY_COUNTS"]
    assert_operator queries.size, :<, 40, query_failure_message("home", 40, queries)
  end

  test "category page renders with fewer than 30 SQL queries" do
    queries = capture_queries { get "/es/c/components/graphics-cards" }

    assert_response :success
    assert_select "article", minimum: 24
    warn "QUERY COUNT category=#{queries.size}" if ENV["PRINT_QUERY_COUNTS"]
    assert_operator queries.size, :<, 30, query_failure_message("category", 30, queries)
  end

  test "listing page renders with fewer than 35 SQL queries" do
    queries = capture_queries { get "/es/l/#{@listing.slug}" }

    assert_response :success
    assert_select "h1", text: @listing.title
    warn "QUERY COUNT listing=#{queries.size}" if ENV["PRINT_QUERY_COUNTS"]
    assert_operator queries.size, :<, 35, query_failure_message("listing", 35, queries)
  end

  private

  def create_demo_like_listings(count)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: File.open(Rails.root.join("test/fixtures/files/gpu.jpg")),
      filename: "gpu.jpg", content_type: "image/jpeg"
    )

    Array.new(count) do |index|
      listing = Listing.create!(
        user: users(:seller),
        store: stores(:seller_store),
        category: categories(:graphics_cards),
        title: "Tarjeta gráfica de alto rendimiento para gaming y creación #{index}",
        description: "Componente revisado y probado, con caja original y todos los accesorios incluidos.",
        price_cents: 49_900 + (index * 1_000),
        original_price_cents: index.even? ? 69_900 + (index * 1_000) : nil,
        condition: index.even? ? :used_like_new : :used_good,
        status: index % 10 == 9 ? :sold : :published,
        published_at: (count - index).minutes.ago,
        quantity: 1,
        specs: { "cpu_brand" => index.even? ? "amd" : "intel", "vram_gb" => 12 },
        labels: [ index.even? ? "mid_range" : "pro_gamer" ],
        tags: %w[gpu nvidia],
        country_code: "ES",
        region: regions(:madrid),
        city: "Madrid",
        shipping_available: true,
        local_pickup: true,
        shipping_price_cents: 500,
        favorites_count: count - index,
        views_count: count - index
      )
      listing.images.attach(blob)
      listing
    end
  end

  def prepare_card_variants
    @listings.each do |listing|
      image = listing.ordered_images.first
      [ [ 640, 480 ], [ 1600, 900 ], [ 1600, 1200 ], [ 2400, 1800 ] ].each do |size|
        image.variant(resize_to_limit: size, format: :webp).processed
      end
    end
  end

  def capture_queries
    queries = []
    callback = lambda do |_name, _start, _finish, _id, payload|
      next if payload[:name] == "SCHEMA"

      sql = payload[:sql].to_s
      next if sql.match?(/\A\s*(BEGIN|COMMIT|SAVEPOINT|RELEASE)/i)

      queries << sql
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries
  end

  def query_failure_message(page, limit, queries)
    "Expected the #{page} page to use fewer than #{limit} SQL queries, got #{queries.size}:\n" \
      "#{queries.map { |sql| sql.first(160) }.join("\n")}"
  end
end
