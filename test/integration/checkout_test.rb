require "test_helper"

class CheckoutTest < ActionDispatch::IntegrationTest
  setup do
    @listing = listings(:published_gpu)
  end

  test "guest completes checkout with bank transfer end to end" do
    post cart_items_path(locale: :es), params: { listing_id: @listing.id }
    assert_response :redirect

    get cart_path(locale: :es)
    assert_response :success
    assert_select "a[href='#{checkout_path(locale: :es)}']", text: I18n.t("cart.checkout_guest", locale: :es)

    get checkout_path(locale: :es)
    assert_response :success
    assert_select "input[name='checkout[email]']"

    post checkout_path(locale: :es), params: {
      checkout: {
        email: "guest@example.com",
        payment_method: "bank_transfer",
        checkout_token: "guest-checkout-token",
        full_name: "Guest Buyer",
        line1: "Calle de Alcalá 1",
        city: "Madrid",
        postal_code: "28001",
        region_id: regions(:madrid).id,
        country_code: "ES",
        delivery: { users(:seller).id.to_s => "shipping" },
        terms_accepted: "1",
        withdrawal_acknowledged: "1"
      }
    }

    assert_redirected_to checkout_confirmation_path(locale: :es)
    order = Order.find_by!(buyer_email: "guest@example.com")
    assert_nil order.buyer
    assert order.pending_payment?
    assert_equal "bank_transfer", order.payment_method
    assert order.guest_access_token.present?
    assert @listing.reload.sold?
    assert_enqueued_email_with OrderMailer, :placed_buyer, args: [ order ]

    follow_redirect!
    assert_response :success
    assert_select "h1", text: I18n.t("checkout.confirmation.title", locale: :es)
    assert_match order.number, response.body

    get order_path(order, locale: :es, token: order.guest_access_token)
    assert_response :success
    assert_select "h1", text: /#{order.number}/
  end

  test "guest order without the access token requires sign in" do
    order = orders(:pending_order)
    order.update_columns(buyer_id: nil, guest_access_token: "guest-token-abc")

    get order_path(order, locale: :es)
    assert_redirected_to new_user_session_path(locale: :es)

    get order_path(order, locale: :es, token: "guest-token-abc")
    assert_response :success
  end

  test "logged-in checkout uses a saved address without duplicating it" do
    sign_in users(:buyer)
    address = addresses(:buyer_address)

    assert_no_difference -> { Address.count } do
      post checkout_path(locale: :es), params: {
        checkout: {
          email: users(:buyer).email,
          address_id: address.id,
          payment_method: "bank_transfer",
          checkout_token: "buyer-saved-address-token",
          delivery: { users(:seller).id.to_s => "shipping" },
          terms_accepted: "1",
          withdrawal_acknowledged: "1"
        }
      }
    end

    assert_redirected_to checkout_confirmation_path(locale: :es)
    order = Order.find_by!(checkout_token: "buyer-saved-address-token")
    assert_equal users(:buyer), order.buyer
    assert_equal address.line1, order.ship_line1
    assert_equal address.postal_code, order.ship_postal_code
    assert_equal address.default, true
  end

  test "logged-in checkout can save a new address" do
    sign_in users(:buyer)

    assert_difference -> { Address.count }, 1 do
      post checkout_path(locale: :es), params: {
        checkout: {
          email: users(:buyer).email,
          payment_method: "bank_transfer",
          checkout_token: "buyer-new-address-token",
          save_address: "1",
          full_name: "Bruno Buyer",
          line1: "Gran Via 10",
          city: "Madrid",
          postal_code: "28013",
          region_id: regions(:madrid).id,
          country_code: "ES",
          delivery: { users(:seller).id.to_s => "shipping" },
          terms_accepted: "1",
          withdrawal_acknowledged: "1"
        }
      }
    end

    address = Address.order(:created_at).last
    assert_equal "Gran Via 10", address.line1
    assert order_exists_with_line1("Gran Via 10")
  end

  test "checkout is blocked and cart hides checkout when disabled" do
    Setting.set("checkout_enabled", false)
    sign_in users(:buyer)

    get cart_path(locale: :es)
    assert_response :success
    assert_select "a[href='#{checkout_path(locale: :es)}']", count: 0
    assert_match I18n.t("cart.checkout_disabled", locale: :es), response.body

    get checkout_path(locale: :es)
    assert_redirected_to cart_path(locale: :es)
  ensure
    Setting.set("checkout_enabled", true)
  end

  private

  def order_exists_with_line1(line1)
    Order.where(ship_line1: line1).exists?
  end
end
