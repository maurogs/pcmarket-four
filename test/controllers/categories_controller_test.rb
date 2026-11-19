require "test_helper"

class CategoriesControllerTest < ActionDispatch::IntegrationTest
  include CatalogHelpers

  setup { create_browse_catalog }

  test "shows published listings of the category" do
    get category_path(categories(:gpus), locale: "en")

    assert_response :success
    assert_select "h1", /Graphics Cards/
    assert_select "turbo-frame#browse_results"
    assert_select "a", text: "NVIDIA GeForce RTX 3060 12GB"
    assert_select "a", text: "AMD Radeon RX 6600 8GB"
    assert_response_not_contains "Pending Graphics Card Should Not Show"
  end

  test "includes listings from descendant categories" do
    get category_path(categories(:components), locale: "en")

    assert_response :success
    assert_select "a", text: "Intel Core i5-12400 Processor"
  end

  test "filters by spec facet" do
    get category_path(categories(:gpus), specs: { gpu_chipset: [ "nvidia" ] }, locale: "en")

    assert_select "a", text: "NVIDIA GeForce RTX 3060 12GB"
    assert_response_not_contains "AMD Radeon RX 6600"
  end

  test "filters by condition" do
    get category_path(categories(:gpus), condition: [ "used_good" ], locale: "en")

    assert_select "a", text: "AMD Radeon RX 6600 8GB"
    assert_response_not_contains "NVIDIA GeForce RTX 3060"
  end

  test "filters by price range (cents)" do
    get category_path(categories(:gpus), min_price: 20_000, locale: "en")

    assert_select "a", text: "NVIDIA GeForce RTX 3060 12GB"
    assert_response_not_contains "AMD Radeon RX 6600"
  end

  test "sorts by price ascending" do
    get category_path(categories(:gpus), sort: "price_asc", locale: "en")

    assert_ordered [ "AMD Radeon RX 6600 8GB", "NVIDIA GeForce RTX 3060 12GB" ]
  end

  test "sorts by newest" do
    get category_path(categories(:gpus), sort: "newest", locale: "en")

    assert_ordered [ "AMD Radeon RX 6600 8GB", "NVIDIA GeForce RTX 3060 12GB" ]
  end

  test "shows active filter pills and clear link" do
    get category_path(categories(:gpus), specs: { gpu_chipset: [ "nvidia" ] }, locale: "en")

    assert_select "a", text: /\ANVIDIA\z/
    assert_select "a", text: "Clear all"
    assert_response_not_contains "AMD Radeon RX 6600"
  end

  test "renders pagination when results span multiple pages" do
    get category_path(categories(:gpus), per_page: 1, page: 2, locale: "en")

    assert_response :success
    assert_select "nav[aria-label=\"Pagination\"]" do
      assert_select "a", text: /Previous/
    end

    get category_path(categories(:gpus), per_page: 1, locale: "en")

    assert_select "nav[aria-label=\"Pagination\"]" do
      assert_select "a", text: /Next/
    end
  end

  test "unknown and inactive categories are 404" do
    get category_path("nope", locale: "en")
    assert_response :not_found

    categories(:cpus).update!(active: false)
    get category_path(categories(:cpus), locale: "en")
    assert_response :not_found
  end

  private

  def assert_ordered(titles)
    positions = titles.map { |title| response.body.index(ERB::Util.html_escape(title)) }
    assert positions.none?(&:nil?), "expected titles #{titles.inspect} in body"
    assert_equal positions.sort, positions, "titles not in expected order"
  end

  def assert_response_contains(text)
    assert_includes response.body, ERB::Util.html_escape(text)
  end

  def assert_response_not_contains(text)
    refute_includes response.body, ERB::Util.html_escape(text)
  end
end
