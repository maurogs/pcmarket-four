require "test_helper"
require "minitest/mock"
require "ostruct"

# Stripe is never called for real: Account.create / AccountLink.create /
# Account.retrieve are stubbed with OpenStruct stand-ins (the service only
# reads .id / .url / the three flags off the response objects).
class Payments::ConnectOnboardingTest < ActiveSupport::TestCase
  RETURN_URL = "https://pcmarket.test/en/seller/payout_account"
  REFRESH_URL = "https://pcmarket.test/en/seller/payout_account"

  setup do
    @store = stores(:confirmed_store)
  end

  def fake_account(id: "acct_123", charges: false, payouts: false, details: false)
    OpenStruct.new(id: id, charges_enabled: charges, payouts_enabled: payouts, details_submitted: details)
  end

  def account_link_for(store, **overrides)
    Payments::ConnectOnboarding.account_link_for(
      store, return_url: RETURN_URL, refresh_url: REFRESH_URL, **overrides
    )
  end

  # --- account_link_for -----------------------------------------------------------

  test "account_link_for creates the Express account once and returns the onboarding url" do
    create_calls = []
    link_calls = []
    first = second = nil
    link = OpenStruct.new(url: "https://connect.stripe.com/setup/c/abc123")

    Stripe::Account.stub(:create, lambda { |params, *| create_calls << params; fake_account }) do
      Stripe::AccountLink.stub(:create, lambda { |params, *| link_calls << params; link }) do
        first = account_link_for(@store)
        second = account_link_for(@store.reload)
      end
    end

    assert_predicate first, :success?
    assert_equal link.url, first.url
    assert_predicate second, :success?
    # The account is created lazily on first use only — the second call reuses it.
    assert_equal 1, create_calls.size
    assert_equal 2, link_calls.size
    assert_equal "acct_123", @store.reload.stripe_account_id
    assert_equal "acct_123", link_calls.first[:account]
    assert_equal RETURN_URL, link_calls.first[:return_url]
    assert_equal REFRESH_URL, link_calls.first[:refresh_url]
    assert_equal "account_onboarding", link_calls.first[:type]
  end

  test "the Express account is requested for Spain with the store's email, kind and capabilities" do
    create_calls = []
    Stripe::Account.stub(:create, lambda { |params, *| create_calls << params; fake_account }) do
      Stripe::AccountLink.stub(:create, ->(*) { OpenStruct.new(url: "https://connect.stripe.com/x") }) do
        assert_predicate account_link_for(@store), :success?
      end
    end

    params = create_calls.first
    assert_equal "express", params[:type]
    assert_equal "ES", params[:country]
    assert_equal @store.user.email, params[:email]
    assert_equal "individual", params[:business_type]
    assert_equal true, params[:capabilities][:transfers][:requested]
    assert_equal true, params[:capabilities][:card_payments][:requested]
    assert_equal @store.id.to_s, params[:metadata][:store_id]
  end

  test "a business store maps to the company business type" do
    @store.update!(kind: :business, business_name: "Retro Corner S.L.", tax_id: "B12345678")
    create_calls = []

    Stripe::Account.stub(:create, lambda { |params, *| create_calls << params; fake_account }) do
      Stripe::AccountLink.stub(:create, ->(*) { OpenStruct.new(url: "https://connect.stripe.com/x") }) do
        assert_predicate account_link_for(@store), :success?
      end
    end

    assert_equal "company", create_calls.first[:business_type]
  end

  test "account_link_for wraps Stripe errors in a translated failure" do
    Stripe::Account.stub(:create, ->(*) { raise Stripe::StripeError, "boom" }) do
      result = account_link_for(@store)
      assert_not_predicate result, :success?
      assert_equal I18n.t("payments.connect.stripe_error"), result.errors.first
    end
    assert_nil @store.reload.stripe_account_id
  end

  # --- sync! ----------------------------------------------------------------------

  test "sync! copies the account flags onto the store and stamps synced_at" do
    @store.update!(stripe_account_id: "acct_123")

    Stripe::Account.stub(:retrieve, lambda { |id, *|
      assert_equal "acct_123", id
      fake_account(charges: true, payouts: true, details: true)
    }) do
      result = Payments::ConnectOnboarding.sync!(@store)
      assert_predicate result, :success?
    end

    @store.reload
    assert @store.stripe_charges_enabled
    assert @store.stripe_payouts_enabled
    assert @store.stripe_details_submitted
    assert_in_delta Time.current.to_f, @store.stripe_synced_at.to_f, 10
  end

  test "sync! keeps flags false when the account is not ready" do
    @store.update!(stripe_account_id: "acct_123", stripe_charges_enabled: true)

    Stripe::Account.stub(:retrieve, ->(*) { fake_account }) do
      assert_predicate Payments::ConnectOnboarding.sync!(@store), :success?
    end

    @store.reload
    assert_not @store.stripe_charges_enabled
    assert_not @store.stripe_payouts_enabled
    assert_not @store.stripe_details_submitted
  end

  test "sync! wraps Stripe errors in a translated failure without touching the flags" do
    @store.update!(stripe_account_id: "acct_123")

    Stripe::Account.stub(:retrieve, ->(*) { raise Stripe::StripeError, "down" }) do
      result = Payments::ConnectOnboarding.sync!(@store)
      assert_not_predicate result, :success?
      assert_equal I18n.t("payments.connect.stripe_error"), result.errors.first
    end
    assert_nil @store.reload.stripe_synced_at
  end
end
