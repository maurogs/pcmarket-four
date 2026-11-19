require "test_helper"

class PcFindersControllerTest < ActionDispatch::IntegrationTest
  include CatalogHelpers

  setup do
    @valorant = Game.create!(slug: "valorant", name: "Valorant", position: 1,
      demand: { "1080p" => { "60" => 20, "144" => 40 }, "1440p" => { "60" => 30, "144" => 60 } })
    @cyberpunk = Game.create!(slug: "cyberpunk-2077", name: "Cyberpunk 2077", position: 2,
      demand: { "1440p" => { "144" => 80 } })

    @strong = gaming_pc(title: "Ryzen 7 RTX 4070 Gaming PC", score: 80, price: 150_000)
    @weak = gaming_pc(title: "Ryzen 5 GTX 1660 Gaming PC", score: 40, price: 90_000)
  end

  # --- Quiz (no selections) -----------------------------------------------------

  test "renders the quiz with gamer-type and game tiles without params" do
    get "/es/pc-finder"

    assert_response :success
    assert_select "form[data-controller=?]", "quiz"
    assert_select "fieldset[data-quiz-target=?]", "step", 7
    assert_select "a[href=?]", "/es/pc-finder?games%5B%5D=valorant"
    assert_select "a[href=?]", "/es/pc-finder?games%5B%5D=cyberpunk-2077"
    assert_select "section[aria-labelledby=?]", "gamer-types-heading"

    # No results block: the sort form only exists once the quiz was answered.
    assert_select "form select[name=?]", "sort", 0
  end

  test "step param sets the quiz start value" do
    get "/en/pc-finder", params: { step: 3 }

    assert_response :success
    assert_select "form[data-controller=?][data-quiz-step-value=?]", "quiz", "3"
  end

  # --- Results ------------------------------------------------------------------

  test "shows matching listings with estimated fps and hides slower builds" do
    get "/en/pc-finder", params: { games: [ "valorant" ], resolution: "1440p", fps: "144" }

    assert_response :success
    assert_select "a", text: @strong.title
    assert_response_not_contains @weak.title

    # Valorant needs 60 at 1440p/144; the 80-score build delivers 144 * 80 / 60.
    assert_response_contains "Valorant"
    assert_response_contains "192 FPS"

    # Results replace the discovery tiles.
    assert_select "section[aria-labelledby=?]", "gamer-types-heading", 0
  end

  test "invalid params fall back to the quiz when no valid game remains" do
    get "/es/pc-finder", params: { games: [ "unknown" ], resolution: "8k", fps: "999", budget: "foo" }

    assert_response :success
    assert_select "form[data-controller=?]", "quiz"
    assert_select "section[aria-labelledby=?]", "gamer-types-heading"
    assert_select "form select[name=?]", "sort", 0
  end

  test "page param paginates results" do
    first = gaming_pc(title: "First Gaming PC", score: 80, price: 100_000)
    24.times { |i| gaming_pc(title: "Filler Gaming PC #{i}", score: 80, price: 100_000) }

    # Budget keeps the setup's @strong/@weak out: 25 matching PCs, 24 per page.
    params = { games: [ "valorant" ], resolution: "1440p", fps: "144", budget: "800_1200" }

    get "/en/pc-finder", params: params.merge(page: 2)
    assert_response :success
    assert_select "nav[aria-label=\"Pagination\"]"
    assert_select "a", text: first.title
    assert_response_not_contains "Filler Gaming PC 23"

    get "/en/pc-finder", params: params
    assert_response :success
    assert_select "a", text: "Filler Gaming PC 23"
    assert_response_not_contains first.title
  end

  # --- i18n ---------------------------------------------------------------------

  I18n.available_locales.map(&:to_s).each do |locale|
    test "renders #{locale} without missing translations" do
      get "/#{locale}/pc-finder"
      assert_response :success
      assert_no_match "translation missing", response.body

      get "/#{locale}/pc-finder", params: { games: [ "valorant" ], resolution: "1440p", fps: "144" }
      assert_response :success
      assert_no_match "translation missing", response.body
    end
  end

  # --- Entry points ---------------------------------------------------------------

  test "mega menu links to the pc finder" do
    get "/en"

    assert_response :success
    assert_select "nav[data-controller=?] a[href=?]", "mega-menu", "/en/pc-finder"
  end

  test "home banner CTA links to the pc finder" do
    get "/en"

    assert_response :success
    assert_select "section[aria-labelledby=?] a[href=?]", "pc-finder-heading", "/en/pc-finder"
  end

  private

  def gaming_pc(score:, price:, tags: [], **overrides)
    listing = publish(create_listing(
      **{ title: "Gaming PC Build #{price}", category: categories(:gaming_pcs), price_cents: price }
        .merge(overrides)
    ))
    listing.update_column(:performance_score, score)
    tags.each { |tag| listing.seller_tags << tag }
    listing
  end

  def assert_response_contains(text)
    assert_includes response.body, ERB::Util.html_escape(text)
  end

  def assert_response_not_contains(text)
    refute_includes response.body, ERB::Util.html_escape(text)
  end
end
