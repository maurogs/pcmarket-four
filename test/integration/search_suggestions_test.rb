require "test_helper"

class SearchSuggestionsTest < ActionDispatch::IntegrationTest
  test "returns matching listings inside a turbo frame" do
    get search_suggestions_path(locale: :es, q: "RTX")

    assert_response :success
    assert_select "turbo-frame#search-suggestions", 1
    assert_select "a[href=?]", "/es/l/#{listings(:published_gpu).slug}"
    assert_select "p", text: I18n.t("layout.search.products")
  end

  test "returns matching categories and stores" do
    get search_suggestions_path(locale: :en, q: "laptop")

    assert_response :success
    assert_select "turbo-frame#search-suggestions"
    assert_includes response.body, I18n.t("layout.search.categories", locale: :en)
  end

  test "short queries return an empty frame" do
    get search_suggestions_path(locale: :es, q: "a")

    assert_response :success
    assert_select "turbo-frame#search-suggestions"
    assert_select "a", count: 0
  end
end
