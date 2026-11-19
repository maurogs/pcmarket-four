require "test_helper"

class SearchesControllerTest < ActionDispatch::IntegrationTest
  include CatalogHelpers

  setup { create_browse_catalog }

  test "renders the search form without a query" do
    get search_path(locale: "en")

    assert_response :success
    assert_select "form input[name=q]"
    assert_select "turbo-frame#browse_results", count: 0
  end

  test "shows results matching the query" do
    get search_path(q: "rtx", locale: "en")

    assert_response :success
    assert_select "turbo-frame#browse_results"
    assert_select "a", text: "NVIDIA GeForce RTX 3060 12GB"
    refute_includes response.body, "Intel Core i5"
  end

  test "shows the empty state when nothing matches" do
    get search_path(q: "zzz-nothing-matches", locale: "en")

    assert_response :success
    assert_select "h2", "No results"
  end
end
