require "test_helper"

class StoreTest < ActiveSupport::TestCase
  test "EnsureForUser creates one store per user named after the username" do
    user = users(:pending)

    store = Stores::EnsureForUser.call(user)

    assert_equal "pendinguser", store.name
    assert_equal "pendinguser", store.slug
    assert_equal store, Stores::EnsureForUser.call(user)
    assert_equal 1, Store.where(user: user).count
  end

  test "slug regenerates when the store is renamed" do
    store = stores(:confirmed_store)

    assert_equal "confirmed-store", store.slug
    store.update!(name: "Retro Corner")

    assert_equal "retro-corner", store.reload.slug
    assert_equal store, Store.find_by_param("retro-corner")
  end

  # Fixtures are inserted straight into the DB and bypass FriendlyId, so
  # history assertions need a model-created store.
  test "renaming a store keeps the old slug resolvable via history" do
    store = Store.create!(user: users(:pending), name: "History Test Store")
    old_slug = store.slug

    store.update!(name: "Renamed History Store")

    assert_equal "renamed-history-store", store.reload.slug
    assert_equal store, Store.find_by_param(old_slug)
    assert_equal store, Store.find_by_param(store.slug)
  end

  test "business stores need identity details" do
    store = stores(:confirmed_store)

    assert_raises(ActiveRecord::RecordInvalid) { store.update!(kind: :business) }

    store.update!(kind: :business, business_name: "Retro Corner S.L.", tax_id: "B12345678")

    assert_predicate store, :business?
    assert_equal "Retro Corner S.L.", store.display_name
  end

  test "display_name prefers the plain name for individuals" do
    assert_equal "Confirmed Store", stores(:confirmed_store).display_name
  end

  test "verified! stamps the timestamp" do
    store = stores(:confirmed_store)
    store.verified!

    assert_predicate store, :verified?
    assert_not_nil store.verified_at
  end

  test "vacation stores are hidden from visible listings" do
    listing = publish(create_listing(title: "Corsair Vengeance LPX 32 GB Kit"))

    stores(:confirmed_store).update_column(:vacation_mode, true)

    assert_not_includes Listing.visible.ids, listing.id
  end

  test "RefreshActiveListingsCount counts published listings only" do
    # Sync the denormalized column with fixture data first, then measure a
    # delta (browse fixtures add published listings to this store).
    Stores::RefreshActiveListingsCount.call(stores(:confirmed_store))
    before = stores(:confirmed_store).reload.active_listings_count
    publish(create_listing(title: "Kingston Fury Beast 16 GB DDR5"))
    create_listing(title: "Crucial P3 1 TB Draft")

    Stores::RefreshActiveListingsCount.call(stores(:confirmed_store))

    assert_equal before + 1, stores(:confirmed_store).reload.active_listings_count
  end
end
