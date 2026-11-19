require "test_helper"

class Accounts::DataExporterTest < ActiveSupport::TestCase
  setup do
    @user = users(:confirmed)
    @other_store = Store.create!(user: users(:pending), name: "Pending Store", slug: "pending-store")
    @listing = publish(create_listing(store: stores(:confirmed_store),
                                      title: "MSI RTX 4070 Gaming X Trio 12GB"))
    @user.follows.create!(store: @other_store)
    @review = create_review(store: @other_store, author: @user, rating: 4,
                            title: "Good seller", body: "Fast and honest.")
    @user.addresses.create!(country: countries(:es), first_name: "Ana", last_name: "López",
                            street_line1: "Calle Mayor 1", city: "Madrid",
                            province: "28", postal_code: "28001")
  end

  test "attaches a JSON export and stamps the generation time" do
    json = Accounts::DataExporter.call(@user)

    @user.reload
    assert_predicate @user.data_export, :attached?
    assert_equal "application/json", @user.data_export.blob.content_type
    assert_not_nil @user.data_export_generated_at
    assert_equal json, @user.data_export.download.force_encoding("UTF-8")
  end

  test "export has one top-level key per data category" do
    payload = JSON.parse(Accounts::DataExporter.call(@user))

    assert_equal %w[generated_at profile addresses notification_preferences
                    store follows reviews], payload.keys
  end

  test "profile section carries the account fields" do
    profile = JSON.parse(Accounts::DataExporter.call(@user))["profile"]

    assert_equal "confirmed@example.com", profile["email"]
    assert_equal "confirmeduser", profile["username"]
    assert_equal "Confirmed", profile["first_name"]
    assert_equal "es", profile["locale"]
  end

  test "addresses, follows and reviews sections carry the records" do
    payload = JSON.parse(Accounts::DataExporter.call(@user))

    assert_equal 1, payload["addresses"].size
    assert_equal "Calle Mayor 1", payload["addresses"].first["street_line1"]
    assert payload["addresses"].first.key?("default_shipping")

    assert_equal [ "Pending Store" ], payload["follows"].pluck("store")

    assert_equal 1, payload["reviews"].size
    assert_equal 4, payload["reviews"].first["rating"]
    assert_equal "Good seller", payload["reviews"].first["title"]
  end

  test "store section carries the store and its listings" do
    store = JSON.parse(Accounts::DataExporter.call(@user))["store"]

    assert_equal "Confirmed Store", store["name"]
    assert_equal "confirmed-store", store["slug"]
    assert_equal 1, store["listings"].size

    listing = store["listings"].first
    assert_equal "MSI RTX 4070 Gaming X Trio 12GB", listing["title"]
    assert_equal 50_000, listing["price_cents"]
    assert_equal "published", listing["status"]
    assert_equal "gpus", listing["category"]
  end

  test "store is null for users without one" do
    loner = User.create!(email: "loner@example.com", username: "loner",
                         password: "password123", confirmed_at: Time.current)
    payload = JSON.parse(Accounts::DataExporter.call(loner))

    assert_nil payload["store"]
    assert_equal [], payload["follows"]
  end
end
