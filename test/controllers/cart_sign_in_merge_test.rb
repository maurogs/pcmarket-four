require "test_helper"

# Guest-cart merge on sign-in (config/initializers/warden_cart_merge.rb).
# These go through a real POST to the Devise session route on purpose: the
# test-mode `sign_in` helper stubs the Warden proxy and never runs the
# after_set_user callbacks, so it cannot exercise the hook. Sign-in uses
# users(:confirmed) because the pending fixture is not confirmed yet.
class CartSignInMergeTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:confirmed)
    seller_store = Store.create!(user: users(:pending), name: "Seller Store", country: countries(:es))
    @listing = publish(create_listing(store: seller_store, price_cents: 25_000, quantity: 3))
    set_setting("checkout_enabled", true)
  end

  test "signing in merges the guest cart into the user's cart" do
    post "/en/cart_items", params: { listing_id: @listing.to_param }
    guest_cart = Cart.guest.last
    assert_equal 1, guest_cart.cart_items.count

    sign_in_by_password

    assert_equal 0, Cart.guest.count, "the guest cart should be destroyed by the merge"

    merged = @user.reload.cart
    assert_not_nil merged
    assert_equal [ @listing ], merged.cart_items.map(&:listing)
    assert_equal 25_000, merged.cart_items.first.unit_price_cents
  end

  test "the merged cart is visible on the cart page after signing in" do
    post "/en/cart_items", params: { listing_id: @listing.to_param }
    sign_in_by_password

    get "/en/cart"

    assert_response :success
    assert_select "a[href=?]", "/en/l/#{@listing.to_param}", minimum: 1
  end

  test "the guest cart cookie is cleared on sign-in" do
    post "/en/cart_items", params: { listing_id: @listing.to_param }

    sign_in_by_password

    set_cookie = response.headers["Set-Cookie"].to_s
    assert_includes set_cookie, "#{Cart::COOKIE}=;", "sign-in must blank the cart cookie"
  end

  test "signing in without a cart cookie creates no carts" do
    assert_no_difference "Cart.count" do
      sign_in_by_password
    end
  end

  test "a guest cart holding the user's own listing merges to nothing" do
    own = publish(create_listing(price_cents: 25_000)) # confirmed user's store
    post "/en/cart_items", params: { listing_id: own.to_param }
    assert_equal 1, Cart.guest.last.cart_items.count

    sign_in_by_password

    assert_equal 0, Cart.guest.count
    assert_empty @user.reload.cart.cart_items
  end

  private

  def sign_in_by_password
    post "/en/users/sign_in", params: { user: { email: @user.email, password: "password123" } }
    assert_response :redirect
  end
end
