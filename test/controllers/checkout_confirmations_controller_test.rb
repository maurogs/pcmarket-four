require "test_helper"

class CheckoutConfirmationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = Store.create!(user: users(:pending), name: "Seller Store", country: countries(:es))
    @listing = publish(create_listing(store: @store, price_cents: 50_000, quantity: 3))
    set_setting("checkout_enabled", true)
    set_setting("guest_checkout_enabled", true)
  end

  test "a guest sees the confirmation of the group they just placed" do
    group = place_via_http

    get "/en/checkout_confirmations/#{group}"

    assert_response :success
    assert_select "h1", text: I18n.t("checkout_confirmations.show.title")
    assert_includes response.body, Order.last.number
    assert_includes response.body, "€500.00"
  end

  test "a guest cannot see a confirmation they did not place" do
    group = place_directly

    get "/en/checkout_confirmations/#{group}"

    assert_response :not_found
  end

  test "the signed-in buyer sees their own confirmation" do
    sign_in users(:confirmed)
    get "/en"
    group = place_directly(buyer: users(:confirmed))

    get "/en/checkout_confirmations/#{group}"

    assert_response :success
  end

  test "a signed-in user cannot see someone else's confirmation" do
    group = place_directly(buyer: users(:confirmed))
    other = User.create!(email: "other@example.com", username: "otheruser",
                         password: "password123", confirmed_at: Time.current)
    sign_in other
    get "/en"

    get "/en/checkout_confirmations/#{group}"

    assert_response :not_found
  end

  test "an unknown group is a 404" do
    get "/en/checkout_confirmations/#{SecureRandom.uuid}"

    assert_response :not_found
  end

  # --- Stripe processing state (Phase 4 step 4b) ------------------------------------

  test "a pending Stripe order shows the processing card and self-refreshes" do
    sign_in users(:confirmed)
    get "/en"
    group = place_directly(buyer: users(:confirmed), payment_method: "stripe")

    get "/en/checkout_confirmations/#{group}"

    assert_response :success
    assert_includes response.body, I18n.t("checkout_confirmations.show.processing.title")
    assert_select "meta[http-equiv=refresh][content*=?]", "tries=1"
  end

  test "the refresh budget is spent after a minute of polling" do
    sign_in users(:confirmed)
    get "/en"
    group = place_directly(buyer: users(:confirmed), payment_method: "stripe")

    get "/en/checkout_confirmations/#{group}?tries=12"

    assert_response :success
    assert_includes response.body, I18n.t("checkout_confirmations.show.processing.title")
    assert_no_match(/http-equiv="refresh"/, response.body)
  end

  test "a paid Stripe order shows the paid next steps and stops refreshing" do
    sign_in users(:confirmed)
    get "/en"
    group = place_directly(buyer: users(:confirmed), payment_method: "stripe")
    Order.where(checkout_group: group).each(&:mark_paid!)

    get "/en/checkout_confirmations/#{group}"

    assert_response :success
    assert_no_match(/http-equiv="refresh"/, response.body)
    assert_includes response.body, I18n.t("checkout_confirmations.show.next_steps.stripe_paid")
  end

  private

  # Places through the real checkout so the group lands in the session.
  def place_via_http
    post "/en/cart_items", params: { listing_id: @listing.to_param }
    post "/en/checkout", params: {
      checkout_form: {
        email: "buyer@example.com",
        first_name: "Mauro", last_name: "Lopez",
        street_line1: "Calle Mayor 1", city: "Madrid",
        province: "28", postal_code: "28001",
        accept_terms: "1", payment_method: "manual"
      }
    }
    Order.last.checkout_group
  end

  # Places straight through the service, bypassing the session.
  def place_directly(buyer: nil, payment_method: "manual")
    cart = Cart.create!(user: buyer)
    cart.add(@listing)
    result = Orders::Placer.call(
      cart: cart, buyer: buyer, email: "buyer@example.com",
      shipping_address: { first_name: "Mauro", last_name: "Lopez", street_line1: "Calle Mayor 1",
                          postal_code: "28001", city: "Madrid", province: "28" },
      shipping_method: "delivery", payment_method: payment_method
    )
    assert_predicate result, :success?, result.errors.join(" ")
    result.checkout_group
  end
end
