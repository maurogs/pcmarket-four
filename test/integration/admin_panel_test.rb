require "test_helper"

class AdminPanelTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:admin) }

  test "dashboard renders with data" do
    get admin_root_path(locale: :es)

    assert_response :success
    assert_select "h1", text: I18n.t("admin.dashboard.title")
    assert_select "svg[role='img']", minimum: 2
    assert_select "a[href='#{admin_moderation_queue_path(locale: :es)}']", minimum: 1
  end

  test "moderation queue renders the pending listing" do
    get admin_moderation_queue_path(locale: :es)

    assert_response :success
    assert_select "article", minimum: 1
    assert_match listings(:pending_review_gpu).title, response.body
    assert_match I18n.t("admin.moderation.approve_feature"), response.body
  end

  test "listings index renders with filters and bulk actions" do
    get admin_listings_path(locale: :es)

    assert_response :success
    assert_select "#admin-filter-status"
    assert_select "#bulk-listings-form"
    assert_select "input[name='listing_ids[]']", minimum: 1
  end

  test "listing detail and edit render" do
    listing = listings(:published_gpu)

    get admin_listing_path(listing, locale: :es)
    assert_response :success
    assert_select "h1", text: listing.title
    assert_match I18n.t("admin.listings.show.history"), response.body

    get edit_admin_listing_path(listing, locale: :es)
    assert_response :success
    assert_select "#listing_game_fps_json"
    assert_select "input[name='listing[labels][]']", minimum: 1
  end

  test "users index, detail and edit render" do
    get admin_users_path(locale: :es)
    assert_response :success
    assert_select "table"

    get admin_user_path(users(:seller), locale: :es)
    assert_response :success
    assert_match users(:seller).email, response.body

    get edit_admin_user_path(users(:seller), locale: :es)
    assert_response :success
    assert_select "#user_username"
  end

  test "stores index, detail and edit render" do
    store = stores(:seller_store)

    get admin_stores_path(locale: :es)
    assert_response :success

    get admin_store_path(store, locale: :es)
    assert_response :success
    assert_match store.name, response.body

    get edit_admin_store_path(store, locale: :es)
    assert_response :success
    assert_select "#store_name"
  end

  test "audit log lists recorded actions" do
    get admin_audit_logs_path(locale: :es)

    assert_response :success
    assert_match I18n.t("admin.audit.actions.listing_approved"), response.body
  end

  test "global search groups results" do
    get admin_search_path(locale: :es, q: "seller")

    assert_response :success
    assert_match users(:seller).email, response.body
  end

  test "placeholder pages explain the next update" do
    get admin_placeholder_path("categories", locale: :es)

    assert_response :success
    assert_match I18n.t("admin.placeholder.coming"), response.body
  end

  test "listings can be filtered and sorted" do
    get admin_listings_path(locale: :es, status: "published", sort: "price_cents", direction: "asc")

    assert_response :success
    assert_no_match listings(:pending_review_gpu).title, response.body
    assert_match listings(:published_gpu).title, response.body
  end

  test "dashboard stays under the query budget" do
    sign_in users(:admin)
    queries = 0
    callback = lambda do |_name, _started, _finished, _unique_id, payload|
      queries += 1 unless payload[:name].in?(%w[SCHEMA TRANSACTION]) || payload[:sql].match?(/\A\s*(BEGIN|COMMIT|SAVEPOINT|RELEASE)/)
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      get admin_root_path(locale: :es)
    end

    assert_response :success
    assert_operator queries, :<, 40, "expected fewer than 40 queries, got #{queries}"
  end
end
