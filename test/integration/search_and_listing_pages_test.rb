require "test_helper"

class SearchAndListingPagesTest < ActionDispatch::IntegrationTest
  setup do
    @category = categories(:graphics_cards)
    @category_path = "/es/c/components/graphics-cards"
    @listing = listings(:published_gpu)
  end

  test "category page renders filters for the effective category filters" do
    get @category_path

    assert_response :success
    assert_select "turbo-frame#listing_results", 1
    assert_select "h1", text: @category.name
    assert_select "summary", text: /Marca del procesador/
    assert_select "a[href=?]", "/es/l/#{@listing.slug}"
    assert_select "details", minimum: 1
  end

  test "filters narrow the result set" do
    get @category_path, params: { min_price: "600" }

    assert_response :success
    assert_select "turbo-frame#listing_results a[href=?]", "/es/l/#{@listing.slug}", count: 0
    assert_select "h3", text: I18n.t("search.results.empty_title")

    get @category_path, params: { condition: [ "used_good" ] }
    assert_select "turbo-frame#listing_results a[href=?]", "/es/l/#{@listing.slug}", count: 0
  end

  test "spec filters use containment and return the matching listing" do
    get @category_path, params: { f: { cpu_brand: [ "intel" ] } }

    assert_response :success
    assert_select "turbo-frame#listing_results a[href=?]", "/es/l/#{@listing.slug}"
  end

  test "anonymous search responses are publicly cacheable for sixty seconds" do
    get @category_path

    assert_includes response.headers["Cache-Control"], "public"
    assert_includes response.headers["Cache-Control"], "max-age=60"
    assert response.headers["ETag"].present?
  end

  test "turbo frame requests render the results frame without the page shell" do
    get @category_path, headers: { "Turbo-Frame" => "listing_results" }

    assert_response :success
    assert_select "turbo-frame#listing_results", 1
    assert_select "header", count: 0
    assert_select "footer", count: 0
  end

  test "filtered pages are noindex and canonical without params" do
    get @category_path, params: { min_price: "100", q: "rtx" }

    assert_response :success
    robots = css_select("meta[name='robots']").first
    assert_equal "noindex,follow", robots["content"]

    canonical = css_select("link[rel='canonical']").first
    assert_equal "http://www.example.com#{@category_path}", canonical["href"]
  end

  test "page two is noindex while page one is indexable" do
    get @category_path
    assert_equal "index,follow", css_select("meta[name='robots']").first["content"]

    get @category_path, params: { page: 2 }
    assert_equal "noindex,follow", css_select("meta[name='robots']").first["content"]
  end

  test "category page emits breadcrumb and item list json-ld" do
    get @category_path

    scripts = css_select("script[type='application/ld+json']").map { |node| JSON.parse(node.text) }
    nodes = scripts.flat_map { |data| Array(data["@graph"]) }
    types = nodes.map { |node| node["@type"] }
    assert_includes types, "BreadcrumbList"
    assert_includes types, "ItemList"

    item_list = nodes.find { |node| node["@type"] == "ItemList" }
    assert_equal 1, item_list["itemListElement"].first["position"]
  end

  test "listing page renders product structured data and the buy box" do
    get "/es/l/#{@listing.slug}"

    assert_response :success
    assert_select "h1", text: @listing.title
    assert_match I18n.t("listings.show.add_to_cart"), response.body

    scripts = css_select("script[type='application/ld+json']").map { |node| JSON.parse(node.text) }
    product = scripts.find { |data| data["@type"] == "Product" }
    assert product.present?
    assert_equal "EUR", product.dig("offers", "priceCurrency")
    assert_equal "https://schema.org/InStock", product.dig("offers", "availability")
    assert_equal "549.00", product.dig("offers", "price")
  end

  test "sold listings stay viewable and report sold availability" do
    sold = listings(:sold_listing)
    get "/es/l/#{sold.slug}"

    assert_response :success
    assert_select "h1", text: sold.title
    product = css_select("script[type='application/ld+json']")
                           .map { |node| JSON.parse(node.text) }
                           .find { |data| data["@type"] == "Product" }
    assert_equal "https://schema.org/SoldOut", product.dig("offers", "availability")
  end

  test "non published listings are only visible to their owner or staff" do
    draft = listings(:draft_listing_approval)

    get "/es/l/#{draft.slug}"
    assert_response :not_found

    sign_in users(:buyer)
    get "/es/l/#{draft.slug}"
    assert_response :not_found

    sign_in users(:seller)
    get "/es/l/#{draft.slug}"
    assert_response :success
    assert_select "p", text: /Borrador/
  end

  test "old slugs redirect permanently to the current slug" do
    FriendlyId::Slug.create!(sluggable: @listing, slug: "old-gpu-slug")

    get "/es/l/old-gpu-slug"

    assert_response :moved_permanently
    assert_redirected_to "/es/l/#{@listing.slug}"
  end

  test "store page renders header, tabs and policies" do
    store = stores(:seller_store)

    get "/es/s/#{store.slug}"
    assert_response :success
    assert_select "h1", text: store.name
    assert_select "a", text: I18n.t("stores.tabs.reviews")

    get "/es/s/#{store.slug}", params: { tab: "about" }
    assert_response :success
    assert_select "h2", text: I18n.t("stores.about.business_title")
    assert_match(/Vendedor profesional/, response.body)

    get "/es/s/#{store.slug}", params: { tab: "reviews" }
    assert_response :success
    assert_select "article", minimum: 1
  end

  test "favourite toggles respond with turbo streams" do
    sign_in users(:buyer)

    assert_difference -> { users(:buyer).favorites.count }, 1 do
      post favorites_path(listing_id: @listing.id),
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action='replace']", minimum: 1

    favorite = users(:buyer).favorites.find_by!(listing: @listing)
    assert_difference -> { users(:buyer).favorites.count }, -1 do
      delete favorite_path(id: favorite.id), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
    assert_response :success
  end

  test "guest favourite intent is completed after signing in" do
    sign_out :user if respond_to?(:sign_out)

    assert_difference -> { Favorite.where(listing: @listing).count }, 1 do
      post favorites_path(listing_id: @listing.id)
      assert_redirected_to new_user_session_path

      sign_in users(:buyer)
      get "/es"
    end
  end

  test "cart items reject own non visible listings and cap quantity by stock" do
    users(:buyer).cart_items.destroy_all
    sign_in users(:seller)
    assert_no_difference -> { CartItem.count } do
      post cart_items_path, params: { listing_id: @listing.id }
    end
    assert_redirected_to "/es/l/#{@listing.slug}"

    sign_in users(:buyer)
    assert_no_difference -> { CartItem.count } do
      post cart_items_path, params: { listing_id: listings(:draft_gpu).id }
    end

    assert_difference -> { CartItem.count }, 1 do
      post cart_items_path, params: { listing_id: @listing.id, quantity: 9 }
    end
    assert_equal 1, CartItem.last.quantity
  end

  test "guest carts use a signed token and merge on login" do
    users(:buyer).cart_items.destroy_all

    assert_difference -> { CartItem.count }, 1 do
      post cart_items_path, params: { listing_id: @listing.id }
    end
    guest_item = CartItem.last
    assert guest_item.cart_token.present?

    post user_session_path(locale: :es), params: {
      user: { email: users(:buyer).email, password: "Password123!" }
    }

    merged = CartItem.find_by(user: users(:buyer), listing: @listing)
    assert merged.present?
    assert_equal 1, merged.quantity
    assert_equal 0, CartItem.where(cart_token: guest_item.cart_token).count
  end

  test "follow toggles respond with turbo streams and update the counter" do
    sign_in users(:buyer)
    follow = follows(:buyer_follows_seller)

    assert_difference -> { Follow.count }, -1 do
      delete follow_path(id: follow.id), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
    assert_response :success

    assert_difference -> { Follow.count }, 1 do
      post follows_path(store_id: stores(:seller_store).id),
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
    assert_response :success
    assert_select "turbo-stream[action='replace']", minimum: 1
  end

  test "reports are created once per user and listing" do
    sign_in users(:buyer)

    assert_no_difference -> { Report.count } do
      post reports_path, params: { listing_id: @listing.id, reason: "spam" }
    end
    assert_redirected_to "/es/l/#{@listing.slug}"
    follow_redirect!
    assert_select "p", text: I18n.t("reports.already_reported")

    assert_difference -> { Report.count }, 1 do
      post reports_path, params: { listing_id: listings(:sold_listing).id, reason: "fraud" }
    end
  end

  test "saved searches are created from the current query" do
    sign_in users(:buyer)

    assert_difference -> { SavedSearch.count }, 1 do
      post saved_searches_path, params: {
        search_query: "q=RTX&min_price=100",
        category_id: @category.id
      }
    end

    saved = SavedSearch.order(:created_at).last
    assert_equal "RTX", saved.query
    assert_equal 10_000, saved.min_price_cents
    assert_equal "RTX", saved.filters.dig("_search", "q")

    get saved_searches_path
    assert_response :success
    assert_select "h1", text: I18n.t("saved_searches.title")
  end
end
