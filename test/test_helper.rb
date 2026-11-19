ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "support/catalog_helpers"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    include CatalogHelpers

    # Rails.cache is not transactional — keep cached settings from leaking
    # between tests (e.g. listing_auto_approve).
    setup { Rails.cache.clear }
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
