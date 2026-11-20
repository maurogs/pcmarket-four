require "test_helper"
require "minitest/mock"
require "ostruct"

# Stripe is never called for real: Account.create / AccountLink.create /
# Account.retrieve are stubbed, and Payments.configured? is stubbed to stand
# in for present credentials (the test env has none).
class Seller::PayoutAccountsControllerTest < ActionDispatch::IntegrationTest
  STRIPE_URL = "https://connect.stripe.com/setup/c/abc123"

  setup do
    @user = users(:confirmed)
    @store = stores(:confirmed_store)
    sign_in @user
    # Warden's test-mode sign_in only injects the user into the *next*
    # request; warm the session up with one successful request first.
    get "/en/seller/payout_account"
    assert_response :success
  end

  def enable_payments!
    set_setting("payments_enabled", true)
  end

  def with_configured_payments
    enable_payments!
    Payments.stub(:configured?, true) { yield }
  end

  def stub_connect(create: nil, link: nil, retrieve: nil)
    Stripe::Account.stub(:create, create || ->(*) { OpenStruct.new(id: "acct_123") }) do
      Stripe::AccountLink.stub(:create, link || ->(*) { OpenStruct.new(url: STRIPE_URL) }) do
        Stripe::Account.stub(:retrieve, retrieve || ->(*) { OpenStruct.new(charges_enabled: false, payouts_enabled: false, details_submitted: false) }) do
          yield
        end
      end
    end
  end

  # --- Authentication & gating -----------------------------------------------------

  test "requires a signed-in user" do
    sign_out @user

    get "/en/seller/payout_account"
    assert_redirected_to "/en/users/sign_in"

    post "/en/seller/payout_account"
    assert_redirected_to "/en/users/sign_in"
  end

  test "a seller without a store is sent to the opening flow" do
    other = User.create!(email: "payout-new@example.com", username: "payoutnew",
                         password: "password123", confirmed_at: Time.current)
    sign_out @user
    sign_in other

    get "/en/seller/payout_account"
    assert_redirected_to "/en/seller/store/new"
  end

  test "payments disabled renders an explanatory page instead of a 404" do
    get "/en/seller/payout_account"

    assert_response :success
    assert_select "h2", text: I18n.t("seller.payout_accounts.show.not_available.title")
    assert_select "form[action=?]", "/en/seller/payout_account", 0
  end

  test "payments enabled but Stripe not configured renders the same page" do
    enable_payments! # no credentials in the test env → Payments.configured? is false

    get "/en/seller/payout_account"

    assert_response :success
    assert_select "h2", text: I18n.t("seller.payout_accounts.show.not_available.title")
  end

  test "create while unavailable bounces to the page with an alert" do
    post "/en/seller/payout_account"

    assert_redirected_to "/en/seller/payout_account"
    assert_equal I18n.t("seller.payout_accounts.create.not_available"), flash[:alert]
  end

  # --- show: statuses --------------------------------------------------------------

  test "connected and configured shows the not connected status with a connect button" do
    with_configured_payments do
      get "/en/seller/payout_account"

      assert_response :success
      assert_select "span", text: I18n.t("seller.payout_accounts.show.status.not_connected")
      assert_select "form[action=?][method=?]", "/en/seller/payout_account", "post"
    end
  end

  test "show syncs a stale account and renders the active status" do
    @store.update!(stripe_account_id: "acct_123")
    retrieve = ->(*) { OpenStruct.new(charges_enabled: true, payouts_enabled: true, details_submitted: true) }

    stub_connect(retrieve: retrieve) do
      with_configured_payments do
        get "/en/seller/payout_account"

        assert_response :success
        assert_select "span", text: I18n.t("seller.payout_accounts.show.status.active")
      end
    end

    @store.reload
    assert @store.stripe_charges_enabled
    assert @store.stripe_payouts_enabled
    assert @store.stripe_details_submitted
    assert_not_nil @store.stripe_synced_at
  end

  test "show renders the pending status while the account is not fully onboarded" do
    @store.update!(stripe_account_id: "acct_123", stripe_details_submitted: true)
    retrieve = ->(*) { OpenStruct.new(charges_enabled: true, payouts_enabled: false, details_submitted: true) }

    stub_connect(retrieve: retrieve) do
      with_configured_payments do
        get "/en/seller/payout_account"

        assert_response :success
        assert_select "span", text: I18n.t("seller.payout_accounts.show.status.pending")
      end
    end
  end

  test "show does not hit Stripe when the flags were synced less than 5 minutes ago" do
    @store.update!(stripe_account_id: "acct_123", stripe_synced_at: 1.minute.ago,
                   stripe_charges_enabled: true, stripe_payouts_enabled: true,
                   stripe_details_submitted: true)
    retrieve = ->(*) { raise "Stripe must not be retrieved for a fresh sync" }

    stub_connect(retrieve: retrieve) do
      with_configured_payments do
        get "/en/seller/payout_account"

        assert_response :success
        assert_select "span", text: I18n.t("seller.payout_accounts.show.status.active")
      end
    end
  end

  test "a sync failure shows an alert banner on the page" do
    @store.update!(stripe_account_id: "acct_123")
    retrieve = ->(*) { raise Stripe::StripeError, "down" }

    stub_connect(retrieve: retrieve) do
      with_configured_payments do
        get "/en/seller/payout_account"

        assert_response :success
        assert_select "[role=?]", "alert", text: I18n.t("payments.connect.stripe_error")
      end
    end
  end

  # --- create ----------------------------------------------------------------------

  test "create redirects off-site to the Stripe onboarding link" do
    stub_connect do
      with_configured_payments do
        post "/en/seller/payout_account"

        assert_response :see_other
        assert_redirected_to STRIPE_URL
      end
    end
    assert_equal "acct_123", @store.reload.stripe_account_id
  end

  test "a Stripe failure on create bounces back with the translated alert" do
    create = ->(*) { raise Stripe::StripeError, "boom" }

    stub_connect(create: create) do
      with_configured_payments do
        post "/en/seller/payout_account"

        assert_redirected_to "/en/seller/payout_account"
        assert_equal I18n.t("payments.connect.stripe_error"), flash[:alert]
      end
    end
    assert_nil @store.reload.stripe_account_id
  end
end
