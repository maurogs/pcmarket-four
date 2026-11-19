require "test_helper"

class PcFinder::RecommenderTest < ActiveSupport::TestCase
  setup do
    @valorant = Game.create!(slug: "valorant", name: "Valorant",
      demand: { "1080p" => { "60" => 30, "144" => 60 }, "1440p" => { "60" => 45 } })
    @cyberpunk = Game.create!(slug: "cyberpunk-2077", name: "Cyberpunk 2077",
      demand: { "1080p" => { "60" => 60, "144" => 90 } })
    @minecraft = Game.create!(slug: "minecraft", name: "Minecraft", demand: {})
    @tiny = Game.create!(slug: "tiny-quest", name: "Tiny Quest",
      demand: { "1080p" => { "240" => 5 } })

    create_spec_filter("cpu_cooler_type", %w[air aio-liquid])
    create_spec_filter("case_form_factor", %w[mid-tower mini-itx-sff])
    create_spec_filter("case_color", %w[white black])
    @rgb = SellerTag.create!(slug: "rgb", name_translations: { "en" => "RGB" })

    @strong = gaming_pc(score: 80, price: 150_000, specs: { "cpu_cooler_type" => [ "air" ] })
    @weak = gaming_pc(score: 40, price: 90_000)

    @other_category = publish(create_listing(
      title: "GeForce RTX 4090 Graphics Card", category: categories(:gpus), price_cents: 99_000
    ))
    @other_category.update_column(:performance_score, 90)

    vacation_store = Stores::EnsureForUser.call(users(:pending))
    vacation_store.update_column(:vacation_mode, true)
    @hidden = gaming_pc(score: 90, price: 99_000, store: vacation_store,
      title: "Vacation Store Gaming PC")
  end

  # --- Empty / required score ------------------------------------------------

  test "no games means no recommendations" do
    result = recommend({})

    assert_empty result.listings
    assert_equal 0, result.pagy.count
    assert_nil result.required_score
    assert_empty result.games
  end

  test "unknown game slugs alone produce no recommendations" do
    assert_empty recommend(games: [ "ghost-of-tsushima" ]).listings
  end

  test "required score is the max across the selected games" do
    result = recommend(games: %w[valorant cyberpunk-2077])

    assert_equal 60, result.required_score
    assert_equal [ @strong.id ], ids(result)
    assert_equal [ @valorant, @cyberpunk ], result.games
  end

  test "games without a target for the selection are skipped" do
    assert_equal 30, recommend(games: %w[valorant minecraft]).required_score
    assert_nil recommend(games: [ "minecraft" ]).required_score
  end

  # --- Hard filters -----------------------------------------------------------

  test "only visible published gaming PCs are recommended" do
    ids = ids(recommend(games: [ "minecraft" ]))

    assert_includes ids, @strong.id
    assert_includes ids, @weak.id
    assert_not_includes ids, @other_category.id
    assert_not_includes ids, @hidden.id
  end

  test "budget narrows results by price" do
    assert_equal [ @weak.id ], ids(recommend(games: [ "valorant" ], budget: "800_1200"))
    assert_empty ids(recommend(games: [ "valorant" ], budget: "over_2000"))
    assert_includes ids(recommend(games: [ "valorant" ], budget: "any")), @strong.id
  end

  test "cooling filter matches the cpu_cooler_type spec" do
    aio = gaming_pc(score: 80, price: 150_000, specs: { "cpu_cooler_type" => [ "aio-liquid" ] })

    assert_equal [ aio.id ], ids(recommend(games: [ "valorant" ], cooling: "aio"))
    assert_equal [ @strong.id ], ids(recommend(games: [ "valorant" ], cooling: "air"))
    assert_equal [ @strong.id, aio.id, @weak.id ].sort,
      ids(recommend(games: [ "valorant" ], cooling: "any")).sort
  end

  test "compact case filter keeps small form factors" do
    sff = gaming_pc(score: 80, price: 150_000, specs: { "case_form_factor" => [ "mini-itx-sff" ] })
    tower = gaming_pc(score: 80, price: 150_000, specs: { "case_form_factor" => [ "mid-tower" ] })

    assert_equal [ sff.id ], ids(recommend(games: [ "valorant" ], case_pref: "compact"))
    assert_includes ids(recommend(games: [ "valorant" ], case_pref: "any")), tower.id
  end

  # --- Soft preferences and ordering -------------------------------------------

  test "vibe boosts ordering but never filters" do
    rgb_pc = gaming_pc(score: 80, price: 150_000, tags: [ @rgb ], title: "RGB Gaming Build")

    result = recommend(games: [ "valorant" ], vibe: "rgb")

    assert_equal [ rgb_pc.id, @strong.id, @weak.id ], ids(result)
  end

  test "case color preference boosts matching builds" do
    white = gaming_pc(score: 70, price: 100_000, specs: { "case_color" => [ "white" ] },
      title: "White Gaming Build")
    plain = gaming_pc(score: 90, price: 100_000, title: "Plain Black Gaming Build")

    assert_equal [ white.id, plain.id, @strong.id, @weak.id ],
      ids(recommend(games: [ "valorant" ], case_pref: "white"))
    assert_equal [ plain.id, white.id, @strong.id, @weak.id ],
      ids(recommend(games: [ "valorant" ], case_pref: "any"))
  end

  test "best_match ranks by performance headroom per euro" do
    cheap = gaming_pc(score: 70, price: 70_000, title: "Budget Boosted Gaming PC")
    pricey = gaming_pc(score: 80, price: 160_000, title: "Overpriced Big Tower PC")

    # Headroom per euro (required 30): cheap 0.57 > strong 0.33 > pricey 0.31 > weak 0.11.
    assert_equal [ cheap.id, @strong.id, pricey.id, @weak.id ], ids(recommend(games: [ "valorant" ]))
  end

  test "sort variants order by price and performance" do
    assert_equal [ @weak.id, @strong.id ], ids(recommend(games: [ "valorant" ], sort: "price_asc"))
    assert_equal [ @strong.id, @weak.id ], ids(recommend(games: [ "valorant" ], sort: "price_desc"))
    assert_equal [ @strong.id, @weak.id ], ids(recommend(games: [ "valorant" ], sort: "performance"))
  end

  # --- estimated_fps --------------------------------------------------------------

  test "estimated_fps scales the target by performance headroom" do
    result = recommend(games: [ "valorant" ])

    assert_equal 160, result.estimated_fps(@strong, @valorant) # 60 * 80 / 30
    assert_equal 80, result.estimated_fps(@weak, @valorant)    # 60 * 40 / 30
  end

  test "estimated_fps is capped at 360" do
    result = recommend(games: [ "tiny-quest" ], fps: 240)

    assert_equal 360, result.estimated_fps(@strong, @tiny) # 240 * 80 / 5 → 3840
  end

  test "estimated_fps is nil without score or demand data" do
    result = recommend(games: [ "valorant" ])
    unscored = gaming_pc(score: nil, price: 100_000, title: "Mystery Box Gaming PC")

    assert_nil result.estimated_fps(unscored, @valorant)
    assert_nil result.estimated_fps(@strong, @minecraft)
  end

  # --- Pagination -------------------------------------------------------------------

  test "results are paginated pagy-style like Listings::Search" do
    result = recommend(games: [ "valorant" ])

    assert_kind_of ActiveRecord::Relation, result.listings
    assert_equal 2, result.pagy.count
    assert_equal 1, result.pagy.pages
    assert_equal 24, result.pagy.limit

    beyond = recommend(games: [ "valorant" ], page: 2)
    assert_empty beyond.listings
    assert_equal 2, beyond.pagy.count
  end

  test "accepts raw params and builds the query itself" do
    result = PcFinder::Recommender.new(games: "valorant", resolution: "1440p").call

    assert_equal 45, result.required_score
    assert_equal [ @strong.id ], ids(result)
  end

  private

  def recommend(params = {})
    PcFinder::Recommender.new(PcFinder::Query.new(params)).call
  end

  def ids(result)
    result.listings.map(&:id)
  end

  def gaming_pc(score:, price:, tags: [], **overrides)
    listing = publish(create_listing(
      **{ title: "Gaming PC Build #{price}", category: categories(:gaming_pcs), price_cents: price }
        .merge(overrides)
    ))
    listing.update_column(:performance_score, score)
    tags.each { |tag| listing.seller_tags << tag }
    listing
  end

  def create_spec_filter(key, values)
    definition = FilterDefinition.create!(key: key, input_type: :multi_select,
      label_translations: { "en" => key.humanize })
    values.each do |value|
      definition.filter_options.create!(value: value, label_translations: { "en" => value.humanize })
    end
    definition
  end
end
