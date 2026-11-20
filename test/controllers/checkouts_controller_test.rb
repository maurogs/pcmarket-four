require "test_helper"
require "minitest/mock"
require "ostruct"

class CheckoutsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # The signed-in fixture (confirmed) must not own the listings it buys,
    # so both stores live under the (unsignable) pending user.
    @store = Store.create!(user: users(:pending), name: "Seller Store", country: countries(:es))
    @listing = publish(create_listing(store: @store, price_cents: 50_000, quantity: 3))
    set_setting("checkout_enabled", true)
    set_setting("guest_checkout_enabled", true)
  end

  # --- access -------------------------------------------------------------------

  test "checkout is 404 while checkout_enabled is off" do
    set_setting("checkout_enabled", false)
    add_to_cart(@listing)

    assert_response :not_found
  end

  test "an empty cart is bounced back to the cart" do
    sign_in users(:confirmed)
    get "/en" # warm up the Warden session (see test conventions)

    get "/en/checkout"

    assert_redirected_to "/en/cart"
    assert_equal I18n.t("checkouts.flashes.empty_cart"), flash[:alert]
  end

  test "a guest sees the form while guest checkout is enabled" do
    add_to_cart(@listing)

    get "/en/checkout"

    assert_response :success
    assert_select "form[action=?]", "/en/checkout"
  end

  test "a guest is sent to sign in when guest checkout is disabled" do
    set_setting("guest_checkout_enabled", false)
    add_to_cart(@listing)

    get "/en/checkout"

    assert_redirected_to new_user_session_path
  end

  test "a signed-in user sees the form with the email prefilled" do
    sign_in users(:confirmed)
    get "/en"
    add_to_cart(@listing)

    get "/en/checkout"

    assert_response :success
    assert_select "input[type=email][value=?]", users(:confirmed).email
  end

  # --- create -------------------------------------------------------------------

  test "an invalid submission re-renders the form with 422" do
    add_to_cart(@listing)

    assert_no_difference "Order.count" do
      post "/en/checkout", params: checkout_params(checkout_form: { postal_code: "nope" })
    end

    assert_response :unprocessable_entity
  end

  test "a valid submission places one order per store and clears the cart" do
    seller2 = User.create!(email: "seller2@example.com", username: "seller2",
                           password: "password123", confirmed_at: Time.current)
    other_store = Store.create!(user: seller2, name: "Other Store", country: countries(:es))
    other_listing = publish(create_listing(store: other_store, price_cents: 25_000, quantity: 5))
    add_to_cart(@listing)
    add_to_cart(other_listing, quantity: 2)

    assert_difference "Order.count", 2 do
      assert_difference "OrderItem.count", 2 do
        post "/en/checkout", params: checkout_params
      end
    end

    group = Order.last.checkout_group
    assert_redirected_to "/en/checkout_confirmations/#{group}"
    assert_equal I18n.t("checkouts.flashes.placed"), flash[:notice]

    assert_equal 0, cart.cart_items.count
    assert_equal 2, @listing.reload.quantity
    assert_equal 3, other_listing.reload.quantity

    orders = Order.where(checkout_group: group).order(:store_id)
    assert_equal [ @store.id, other_store.id ].sort, orders.map(&:store_id).sort
    assert orders.all? { |o| o.pending? && o.payment_method == "manual" }
    assert_equal "buyer@example.com", orders.first.buyer_email
    assert_nil orders.first.buyer_id
  end

  test "a signed-in buyer is stamped on the orders" do
    sign_in users(:confirmed)
    get "/en"
    add_to_cart(@listing)

    post "/en/checkout", params: checkout_params(checkout_form: { email: "" })

    assert_equal users(:confirmed), Order.last.buyer
  end

  test "a chosen saved address is used for shipping" do
    address = Address.create!(user: users(:confirmed), country: countries(:es),
                              first_name: "Ana", last_name: "Rios", street_line1: "Avinguda Diagonal 200",
                              postal_code: "08018", city: "Barcelona", province: "08")
    sign_in users(:confirmed)
    get "/en"
    add_to_cart(@listing)

    post "/en/checkout", params: checkout_params(
      checkout_form: { address_id: address.id, first_name: "", postal_code: "" }
    )

    assert_response :redirect
    assert_equal "Avinguda Diagonal 200", Order.last.shipping_address["street_line1"]
  end

  test "the inline address is saved when the buyer opts in" do
    sign_in users(:confirmed)
    get "/en"
    add_to_cart(@listing)

    assert_difference "users(:confirmed).addresses.count", 1 do
      post "/en/checkout", params: checkout_params(checkout_form: { save_address: "1" })
    end
  end

  test "a cart that changed under the buyer goes back to the cart" do
    add_to_cart(@listing)
    @listing.update_column(:quantity, 0)

    assert_no_difference "Order.count" do
      post "/en/checkout", params: checkout_params(checkout_form: { email: "buyer@example.com" })
    end

    assert_redirected_to "/en/cart"
    assert_includes flash[:alert], I18n.t("orders.placer.errors.listing_unavailable", title: @listing.title)
  end

  # --- Stripe payments (Phase 4 step 4b) -------------------------------------------

  test "checkout with payments on redirects to Stripe and stamps the session" do
    enable_payments
    add_to_cart(@listing)

    Payments.stub(:configured?, true) do
      Stripe::Checkout::Session.stub(:create, ->(*) { stripe_session }) do
        post "/en/checkout", params: checkout_params(checkout_form: { payment_method: "stripe" })
      end
    end

    assert_redirected_to "https://checkout.stripe.com/pay/cs_test_1"
    order = Order.last
    assert_equal "stripe", order.payment_method
    assert_predicate order, :pending?
    assert_equal "cs_test_1", order.stripe_checkout_session_id
  end

  test "a Stripe failure cancels the placed orders and restores the stock" do
    enable_payments
    add_to_cart(@listing)

    Payments.stub(:configured?, true) do
      Stripe::Checkout::Session.stub(:create, ->(*) { raise Stripe::StripeError, "boom" }) do
        post "/en/checkout", params: checkout_params(checkout_form: { payment_method: "stripe" })
      end
    end

    assert_redirected_to "/en/cart"
    assert_includes flash[:alert], I18n.t("payments.checkout.stripe_error")
    order = Order.last
    assert_predicate order, :cancelled?
    assert_equal "payment_session_failed", order.cancel_reason
    assert_equal 3, @listing.reload.quantity
  end

  test "a store that cannot take payments falls the whole checkout back to manual" do
    set_setting("payments_enabled", true)
    # @store is deliberately NOT payment-ready (stripe_charges_enabled stays false).
    add_to_cart(@listing)

    Payments.stub(:configured?, true) do
      Stripe::Checkout::Session.stub(:create, ->(*) { flunk "must not create a session" }) do
        post "/en/checkout", params: checkout_params(checkout_form: { payment_method: "stripe" })
      end
    end

    order = Order.last
    assert_predicate order, :pending?
    assert_equal "manual", order.payment_method
    assert_redirected_to "/en/checkout_confirmations/#{order.checkout_group}"
    assert_includes flash[:alert], I18n.t("checkouts.flashes.stripe_fallback")
    assert_equal I18n.t("checkouts.flashes.placed"), flash[:notice]
  end

  test "checkout stays manual while payments are off" do
    add_to_cart(@listing)

    post "/en/checkout", params: checkout_params(checkout_form: { payment_method: "stripe" })

    assert_redirected_to "/en/checkout_confirmations/#{Order.last.checkout_group}"
    assert_equal "manual", Order.last.payment_method
  end

  private

  def enable_payments
    set_setting("payments_enabled", true)
    @store.update!(stripe_charges_enabled: true)
  end

  def stripe_session
    OpenStruct.new(id: "cs_test_1", url: "https://checkout.stripe.com/pay/cs_test_1")
  end

  # The cart the requests above accumulate for the current visitor.
  def cart
    @cart ||= Cart.order(:id).last
  end

  def add_to_cart(listing, quantity: 1)
    quantity.times { post "/en/cart_items", params: { listing_id: listing.to_param } }
  end

  def checkout_params(overrides = {})
    {
      checkout_form: {
        email: "buyer@example.com",
        first_name: "Mauro", last_name: "Lopez",
        street_line1: "Calle Mayor 1", city: "Madrid",
        province: "28", postal_code: "28001", phone: "600123456",
        accept_terms: "1", payment_method: "manual"
      }
    }.deep_merge(overrides)
  end
end
