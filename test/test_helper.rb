ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "bcrypt"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    setup { Rails.cache.clear }
    # Add more helper methods to be used by all tests here...
  end
end

module OrderTestHelper
  def create_order(status: :pending_payment, buyer: nil, seller: nil, store: nil,
                   fulfilment: :shipping, payment_method: "stripe", listing: nil,
                   price_cents: 10_000, quantity: 1, locale: "es", **attributes)
    buyer ||= users(:buyer)
    seller ||= users(:seller)
    listing ||= listings(:published_gpu)

    order = Order.create!(
      buyer: buyer,
      seller: seller,
      store: store || seller.store,
      status: :pending_payment,
      fulfilment: fulfilment,
      buyer_email: buyer&.email.presence || "guest@example.com",
      payment_method: payment_method,
      currency: "EUR",
      locale: locale,
      **attributes
    )
    order.order_items.create!(listing: listing, title_snapshot: listing.title,
                              price_cents: price_cents, quantity: quantity)

    timestamps = status_timestamps(status)
    order.update_columns(
      subtotal_cents: price_cents * quantity,
      total_cents: price_cents * quantity,
      status: Order.statuses[status],
      **timestamps
    )
    order.reload
  end

  def status_timestamps(status)
    now = Time.current
    case status.to_s
    when "paid" then { paid_at: now }
    when "shipped" then { paid_at: now, shipped_at: now }
    when "delivered" then { paid_at: now, shipped_at: 1.day.ago, delivered_at: 1.day.ago }
    when "completed" then { paid_at: now, shipped_at: 3.days.ago, delivered_at: 3.days.ago, completed_at: 1.day.ago }
    when "disputed" then { paid_at: now, shipped_at: 1.day.ago, disputed_at: now }
    when "cancelled" then { cancelled_at: now }
    when "refunded" then { paid_at: now, refunded_at: now }
    else {}
    end
  end
end

class ActiveSupport::TestCase
  include OrderTestHelper
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActionMailer::TestHelper
end
