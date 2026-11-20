require "test_helper"

class CartsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # The signed-in fixture (confirmed) must not own the listings it buys,
    # and users(:pending) cannot sign in (not confirmed yet), so listings
    # live in a store owned by the pending user.
    seller_store = Store.create!(user: users(:pending), name: "Seller Store", country: countries(:es))
    @listing = publish(create_listing(store: seller_store, price_cents: 50_000, quantity: 3))
    set_setting("checkout_enabled", true)
  end

  test "guests without a cart cookie see the empty state without a cart row" do
    assert_no_difference "Cart.count" do
      get "/en/cart"
    end

    assert_response :success
    assert_select "h2", text: I18n.t("carts.show.empty.title")
  end

  test "a guest sees the items behind their cart cookie" do
    post "/en/cart_items", params: { listing_id: @listing.to_param }
    assert_response :redirect

    get "/en/cart"

    assert_response :success
    assert_select "a[href=?]", "/en/l/#{@listing.to_param}", minimum: 1
    assert_includes response.body, "€500.00"
  end

  test "signed-in users get their cart created lazily" do
    sign_in users(:confirmed)
    get "/en" # warm up the Warden session (see test conventions)

    assert_difference "Cart.count" do
      get "/en/cart"
    end
    assert_response :success

    assert_no_difference "Cart.count" do
      get "/en/cart"
    end
    assert users(:confirmed).reload.cart
  end

  test "the page refreshes the cart and reports removed items" do
    cart = Cart.create!(user: users(:confirmed))
    cart.add(@listing)
    @listing.update_columns(status: "sold")

    sign_in users(:confirmed)
    get "/en" # warm up the Warden session
    get "/en/cart"

    assert_response :success
    assert_empty cart.cart_items.reload
    # The notice wraps the title in literal quotes, which the view HTML-escapes,
    # so match on the unescaped text content instead of the raw body.
    assert_select "p", text: I18n.t("carts.notices.removed", listing: @listing.title)
  end

  test "the checkout CTA is a disabled Soon placeholder" do
    cart = Cart.create!(user: users(:confirmed))
    cart.add(@listing)

    sign_in users(:confirmed)
    get "/en" # warm up the Warden session
    get "/en/cart"

    assert_response :success
    assert_select "span[aria-disabled=true]", text: /#{I18n.t("account_menu.soon")}/
  end

  test "the whole page 404s while checkout is disabled" do
    set_setting("checkout_enabled", false)

    get "/en/cart"

    assert_response :not_found
  end

  test "the header hides the cart link while checkout is disabled" do
    get "/en"
    assert_select "a[aria-label=?]", I18n.t("nav.cart")

    set_setting("checkout_enabled", false)
    get "/en"

    assert_response :success
    assert_select "a[aria-label=?]", I18n.t("nav.cart"), count: 0
  end

  test "the header badge counts the units of a signed-in user" do
    cart = Cart.create!(user: users(:confirmed))
    cart.add(@listing, quantity: 2)

    sign_in users(:confirmed)
    get "/en" # warm up the Warden session
    get "/en"

    assert_select "#cart_count", text: "2"
  end
end
