require "test_helper"

class PaymentsAvailabilityTest < ActiveSupport::TestCase
  setup do
    @summary = CartSummary.for(user: users(:buyer))
  end

  test "offers bank transfer by default" do
    availability = Payments::Availability.new(@summary)

    assert availability.available?("bank_transfer")
    assert_includes availability.options, "bank_transfer"
    assert_not availability.available?("cash_on_pickup")
    assert_not availability.available?("stripe")
  end

  test "offers cash on pickup only when every group is pickup only" do
    pickup_listing = Listing.create!(
      user: users(:seller), category: categories(:cpus),
      title: "Pickup only processor #{SecureRandom.hex(3)}",
      description: "A sufficiently detailed description for a pickup-only listing.",
      price_cents: 9_000, condition: :used_good, status: :published,
      published_at: Time.current, quantity: 1, country_code: "ES",
      region: regions(:madrid), city: "Madrid", postal_code: "28001",
      shipping_available: false, local_pickup: true, ships_within_days: 2
    )
    CartItem.create!(cart_token: "pickup-token", listing: pickup_listing, quantity: 1)
    summary = CartSummary.for(token: "pickup-token")

    assert Payments::Availability.new(summary).available?("cash_on_pickup")
    assert_not Payments::Availability.new(@summary).available?("cash_on_pickup")
  end

  test "offers stripe only when enabled and configured" do
    Setting.set("stripe_enabled", true)

    with_env("STRIPE_SECRET_KEY", "sk_test_123") do
      assert Payments::Availability.new(@summary).available?("stripe")
    end

    with_env("STRIPE_SECRET_KEY", nil) do
      assert_not Payments::Availability.new(@summary).available?("stripe")
    end
  ensure
    Setting.set("stripe_enabled", false)
  end

  test "respects the bank transfer setting" do
    Setting.set("payment_bank_transfer_enabled", false)

    assert_not Payments::Availability.new(@summary).available?("bank_transfer")
    assert_empty Payments::Availability.new(@summary).options
  ensure
    Setting.set("payment_bank_transfer_enabled", true)
  end

  private

  def with_env(key, value)
    previous = ENV[key]
    ENV[key] = value
    yield
  ensure
    ENV[key] = previous
  end
end
