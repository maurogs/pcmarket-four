require "test_helper"

class PcFinder::QueryTest < ActiveSupport::TestCase
  setup do
    @cyberpunk = Game.create!(slug: "cyberpunk-2077", name: "Cyberpunk 2077", position: 1,
      demand: { "1080p" => { "60" => 45 } })
    @valorant = Game.create!(slug: "valorant", name: "Valorant", position: 2,
      demand: { "1080p" => { "60" => 5 } })
    @fortnite = Game.create!(slug: "fortnite", name: "Fortnite", position: 3)
    @retired = Game.create!(slug: "retired-game", name: "Retired Game", active: false)
    @rgb = SellerTag.create!(slug: "rgb", name_translations: { "en" => "RGB" })
    SellerTag.create!(slug: "retro", name_translations: { "en" => "Retro" }, active: false)
  end

  # --- Defaults and sanitization -------------------------------------------

  test "empty params fall back to every default" do
    query = PcFinder::Query.new

    assert_empty query.games
    assert_equal "1080p", query.resolution
    assert_equal 60, query.fps
    assert_equal "any", query.budget
    assert_equal "any", query.case_pref
    assert_equal "any", query.cooling
    assert_nil query.vibe
    assert_equal "best_match", query.sort
    assert_equal 1, query.page
    assert_not_predicate query, :present?
  end

  test "invalid values silently fall back to defaults" do
    query = PcFinder::Query.new(
      resolution: "4k", fps: "75", budget: "cheap", case_pref: "rgb",
      cooling: "water", vibe: "nope", sort: "random", page: "-2"
    )

    assert_equal "1080p", query.resolution
    assert_equal 60, query.fps
    assert_equal "any", query.budget
    assert_equal "any", query.case_pref
    assert_equal "any", query.cooling
    assert_nil query.vibe
    assert_equal "best_match", query.sort
    assert_equal 1, query.page
  end

  test "valid values are kept" do
    query = PcFinder::Query.new(
      resolution: "2160p", fps: "240", budget: "1200_2000", case_pref: "compact",
      cooling: "aio", vibe: "rgb", sort: "price_asc", page: "3"
    )

    assert_equal "2160p", query.resolution
    assert_equal 240, query.fps
    assert_equal "1200_2000", query.budget
    assert_equal "compact", query.case_pref
    assert_equal "aio", query.cooling
    assert_equal "rgb", query.vibe
    assert_equal "price_asc", query.sort
    assert_equal 3, query.page
  end

  # --- Games ----------------------------------------------------------------

  test "games keeps existing active slugs in request order, max 3" do
    Game.create!(slug: "hades", name: "Hades")
    query = PcFinder::Query.new(
      games: [ "valorant", "retired-game", "fortnite", "ghost-of-tsushima", "valorant", "cyberpunk-2077", "hades" ]
    )

    assert_equal [ @valorant, @fortnite, @cyberpunk ], query.games
    assert_predicate query, :present?
  end

  test "games accepts a comma-separated string" do
    query = PcFinder::Query.new(games: "valorant, cyberpunk-2077")

    assert_equal [ @valorant, @cyberpunk ], query.games
  end

  test "unknown or inactive game slugs alone leave the query blank" do
    query = PcFinder::Query.new(games: [ "retired-game", "nope" ])

    assert_empty query.games
    assert_not_predicate query, :present?
  end

  test "vibe keeps only existing active seller tag slugs" do
    assert_equal "rgb", PcFinder::Query.new(vibe: "rgb").vibe
    assert_nil PcFinder::Query.new(vibe: "retro").vibe
    assert_nil PcFinder::Query.new(vibe: "rgb rgb").vibe # not a valid slug shape
  end

  # --- Budget ----------------------------------------------------------------

  test "budget maps to min/max cents" do
    assert_equal [ nil, nil ], PcFinder::Query.new.budget_price_range
    assert_equal [ nil, 80_000 ], PcFinder::Query.new(budget: "under_800").budget_price_range
    assert_equal [ 80_000, 120_000 ], PcFinder::Query.new(budget: "800_1200").budget_price_range
    assert_equal [ 120_000, 200_000 ], PcFinder::Query.new(budget: "1200_2000").budget_price_range
    assert_equal [ 200_000, nil ], PcFinder::Query.new(budget: "over_2000").budget_price_range
  end

  # --- to_params ---------------------------------------------------------------

  test "to_params round-trips through a new query" do
    query = PcFinder::Query.new(
      games: %w[valorant cyberpunk-2077], resolution: "1440p", fps: 144, budget: "800_1200",
      case_pref: "white", cooling: "aio", vibe: "rgb", sort: "price_desc", page: 4
    )
    params = query.to_params

    assert_equal %w[valorant cyberpunk-2077], params["games"]
    assert_equal "1440p", params["resolution"]
    assert_equal 144, params["fps"]
    assert_equal "800_1200", params["budget"]
    assert_equal "white", params["case_pref"]
    assert_equal "aio", params["cooling"]
    assert_equal "rgb", params["vibe"]
    assert_equal "price_desc", params["sort"]
    assert_equal 4, params["page"]

    assert_equal params, PcFinder::Query.new(params).to_params
  end

  test "to_params omits blank selections and the first page" do
    params = PcFinder::Query.new(games: "valorant").to_params

    assert_not_includes params.keys, "vibe"
    assert_not_includes params.keys, "page"
    assert_equal [ "valorant" ], params["games"]
  end

  test "accepts ActionController::Parameters" do
    query = PcFinder::Query.new(ActionController::Parameters.new("games" => "valorant", "fps" => "144"))

    assert_equal [ @valorant ], query.games
    assert_equal 144, query.fps
  end
end
