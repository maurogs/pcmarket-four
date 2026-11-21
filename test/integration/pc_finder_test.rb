require "test_helper"

class PcFinderTest < ActionDispatch::IntegrationTest
  test "quiz renders as a plain GET form without JavaScript" do
    get pc_finder_path(locale: :en)

    assert_response :success
    assert_select "form[action=?][method=get]", pc_finder_results_path(locale: :en)
    assert_select "input[name='games[]']", minimum: 2
    assert_select "input[name='resolution']"
    assert_select "input[name='fps']"
    assert_select "input[name='budget']"
    assert_select "input[type=submit]"
  end

  test "results page scores listings and is noindex" do
    pc = create_gaming_pc(gpu: "RTX 4070", price_cents: 75_000,
                          game_fps: { "fortnite" => { "1080p" => 144 } })

    get pc_finder_results_path(locale: :en, games: [ "fortnite" ], resolution: "1080p",
                               fps: 60, budget: "under_800", sort: "price_asc")

    assert_response :success
    assert_includes response.body, "noindex"
    assert_select "article", minimum: 1
    assert_includes response.body, pc.title
  end

  test "results show an empty state when nothing matches" do
    get pc_finder_results_path(locale: :en, games: [ "fortnite" ], resolution: "4k",
                               fps: 240, budget: "under_800")

    assert_response :success
    assert_includes response.body, I18n.t("pc_finder.results.empty_title", locale: :en)
  end
end
