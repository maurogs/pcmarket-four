require "test_helper"

# db/seeds/development/* must stay out of every other environment: db/seeds.rb
# gates them on Rails.env.development? && ENV["DEMO"].
class DemoSeedTest < ActionDispatch::IntegrationTest
  test "demo seed files are not loaded in the test environment" do
    assert_not_predicate Rails.env, :development?, "seed gate depends on the test env"

    ENV["DEMO"] = "1"
    assert_no_difference [ "User.count", "Store.count", "Listing.count" ] do
      load Rails.root.join("db/seeds.rb")
    end
    assert_equal 0, User.where("email LIKE ?", "%@demo.example.com").count
  end
end
