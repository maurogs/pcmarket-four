ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "bcrypt"
require "webmock/minitest"
WebMock.disable_net_connect!(allow_localhost: true)
require_relative "support/api_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    setup do
      Rails.cache.clear
      Rack::Attack.reset!
      Rack::Attack.enabled = false
    end

    teardown { Rack::Attack.enabled = false }
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

module PcFinderTestHelper
  def create_gaming_pc(gpu:, price_cents:, game_fps: {}, tags: [], specs: {}, title: nil, status: :published)
    category = Category.find_or_create_by!(slug: "gaming-pcs") do |record|
      record.names = { "es" => "PC gaming", "en" => "Gaming PCs" }
      record.position = 99
      record.active = true
    end

    Listing.create!(
      user: users(:seller),
      store: users(:seller).store,
      category: category,
      title: title || "Gaming PC with #{gpu} ready for testing",
      description: "A complete gaming desktop in good condition with a #{gpu} graphics card.",
      price_cents: price_cents,
      condition: :used_good,
      status: status,
      published_at: Time.current,
      quantity: 1,
      country_code: "ES",
      specs: specs.merge("gpu_model" => gpu),
      game_fps: game_fps,
      tags: tags
    )
  end
end

class ActiveSupport::TestCase
  include PcFinderTestHelper
end
