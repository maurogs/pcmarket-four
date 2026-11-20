require "test_helper"

class CartItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Signed-in tests use users(:confirmed) (the only confirmed fixture), so
    # the bought listing lives in another user's store.
    @user = users(:confirmed)
    seller_store = Store.create!(user: users(:pending), name: "Seller Store", country: countries(:es))
    @listing = publish(create_listing(store: seller_store, price_cents: 25_000, quantity: 3))
    set_setting("checkout_enabled", true)
  end

  # --- Create (add to cart) -----------------------------------------------------

  test "a guest add creates a cookie cart with the snapshotted price" do
    assert_difference "Cart.guest.count" do
      post "/en/cart_items", params: { listing_id: @listing.to_param }
    end

    assert_redirected_to "/en/cart"
    cart = Cart.guest.last
    assert_not_empty cart.token
    assert_not_empty response.cookies[Cart::COOKIE]

    item = cart.cart_items.first
    assert_equal @listing, item.listing
    assert_equal 25_000, item.unit_price_cents
    assert_equal I18n.t("cart_items.flashes.added"), flash[:notice]
  end

  test "the guest cart cookie is signed and httponly" do
    post "/en/cart_items", params: { listing_id: @listing.to_param }
    cart = Cart.guest.last

    set_cookie = response.headers["Set-Cookie"].to_a.find { |c| c.start_with?("#{Cart::COOKIE}=") }
    assert_not_nil set_cookie, "expected a Set-Cookie header for the cart cookie"
    assert_includes set_cookie, "httponly"
    assert_not_includes set_cookie, cart.token, "the cookie value must be signed, not the raw token"
  end

  test "the guest cookie is reused across adds" do
    post "/en/cart_items", params: { listing_id: @listing.to_param }

    other = publish(create_listing(title: "AMD Radeon RX 6600 8GB"))
    post "/en/cart_items", params: { listing_id: other.to_param }

    assert_equal 1, Cart.guest.count
    assert_equal 2, Cart.guest.last.cart_items.count
  end

  test "a signed-in user add lands in their own cart" do
    sign_in @user
    get "/en" # warm up the Warden session

    assert_difference "CartItem.count", 1 do
      post "/en/cart_items", params: { listing_id: @listing.to_param }
    end

    assert_redirected_to "/en/cart"
    assert_empty Cart.guest
    assert_equal 1, @user.reload.cart.cart_items.count
  end

  test "adding your own listing is refused" do
    own = publish(create_listing(title: "Owned Graphics Card")) # confirmed user's store
    sign_in users(:confirmed)
    get "/en" # warm up the Warden session

    post "/en/cart_items", params: { listing_id: own.to_param }

    assert_response :redirect
    assert_equal I18n.t("cart_items.flashes.own_listing"), flash[:alert]
    assert_empty users(:confirmed).reload.cart.cart_items
  end

  test "adding an invisible listing is refused" do
    draft = create_listing(title: "Draft GPU")

    post "/en/cart_items", params: { listing_id: draft.to_param }

    assert_response :redirect
    assert_equal I18n.t("cart_items.flashes.not_available"), flash[:alert]
    assert_equal 0, CartItem.count
  end

  test "buy_now adds and redirects to the cart" do
    post "/en/cart_items", params: { listing_id: @listing.to_param, buy_now: "1" }

    assert_redirected_to "/en/cart"
    assert_equal 1, Cart.guest.last.cart_items.count
  end

  test "turbo stream adds refresh the badge and the toast area" do
    post "/en/cart_items", params: { listing_id: @listing.to_param },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_match "turbo-stream", response.media_type
    assert_includes response.body, %(target="cart_count")
    assert_includes response.body, %(target="toasts")
    assert_includes response.body, I18n.t("cart_items.flashes.added")
  end

  # --- Update (quantity) ----------------------------------------------------------

  test "update changes the quantity" do
    item = add_guest_item

    patch "/en/cart_items/#{item.id}", params: { quantity: "3" }

    assert_redirected_to "/en/cart"
    assert_equal 3, item.reload.quantity
    assert_equal I18n.t("cart_items.flashes.updated"), flash[:notice]
  end

  test "update caps the quantity at the listing stock" do
    item = add_guest_item

    patch "/en/cart_items/#{item.id}", params: { quantity: "99" }

    assert_equal 3, item.reload.quantity
    assert_equal I18n.t("cart_items.flashes.capped", count: 3), flash[:alert]
  end

  test "updating another visitor's item 404s" do
    cart = Cart.create!
    item = cart.cart_items.create!(listing: @listing, quantity: 1, unit_price_cents: 25_000)

    patch "/en/cart_items/#{item.id}", params: { quantity: "2" }

    assert_response :not_found
    assert_equal 1, item.reload.quantity
  end

  # --- Destroy (remove) -------------------------------------------------------------

  test "destroy removes the item" do
    item = add_guest_item

    assert_difference "CartItem.count", -1 do
      delete "/en/cart_items/#{item.id}"
    end

    assert_redirected_to "/en/cart"
    assert_equal I18n.t("cart_items.flashes.removed"), flash[:notice]
  end

  test "turbo stream destroy refreshes the badge" do
    item = add_guest_item

    delete "/en/cart_items/#{item.id}", headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_match "turbo-stream", response.media_type
    assert_includes response.body, %(target="cart_count")
  end

  # --- Feature flag -------------------------------------------------------------------

  test "every route 404s while checkout is disabled" do
    set_setting("checkout_enabled", false)

    post "/en/cart_items", params: { listing_id: @listing.to_param }
    assert_response :not_found
    assert_empty Cart.guest

    cart = Cart.create!
    item = cart.cart_items.create!(listing: @listing, quantity: 1, unit_price_cents: 25_000)
    patch "/en/cart_items/#{item.id}", params: { quantity: "2" }
    assert_response :not_found
    delete "/en/cart_items/#{item.id}"
    assert_response :not_found
  end

  private

  # Adds the listing through the real endpoint so the guest cart cookie is
  # set (and carried by the integration session) exactly like in the browser.
  def add_guest_item
    post "/en/cart_items", params: { listing_id: @listing.to_param }
    Cart.guest.last.cart_items.first
  end
end
