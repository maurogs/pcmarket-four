require "test_helper"

class SellerAreaTest < ActionDispatch::IntegrationTest
  setup do
    @seller = users(:seller)
    @store = stores(:seller_store)
    @listing = listings(:published_gpu)
  end

  test "requires authentication" do
    get seller_root_path(locale: :es)
    assert_redirected_to new_user_session_path(locale: :es)
  end

  test "renders the dashboard without store data" do
    user = User.create!(
      email: "fresh-seller@example.com", password: "Password123!",
      username: "Fresh-Seller#1", country_code: "ES", confirmed_at: Time.current,
      terms_accepted_at: Time.current
    )
    sign_in user

    get seller_root_path

    assert_response :success
    assert_select "h2", text: I18n.t("seller.dashboard.title")
    assert_select "[role=progressbar]"
    assert_match I18n.t("seller.dashboard.empty_recent"), response.body
  end

  test "renders the dashboard with data" do
    sign_in @seller

    get seller_root_path

    assert_response :success
    assert_select "html[lang=es]"
    assert_select "svg[role=img]"
    assert_select "table.sr-only"
    assert_match @store.name, response.body
    assert_match I18n.t("seller.dashboard.metrics.sales"), response.body
  end

  test "dashboard stays under thirty queries" do
    sign_in @seller
    queries = []
    callback = lambda do |_name, _start, _finish, _id, payload|
      next if payload[:name].in?(%w[SCHEMA TRANSACTION])
      next if payload[:cached]

      queries << payload[:sql]
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      get seller_root_path
    end

    assert_response :success
    assert_operator queries.size, :<, 30, "expected fewer than 30 queries, got #{queries.size}:\n#{queries.join("\n")}"
  end

  test "store profile update regenerates the slug and redirects the old URL" do
    sign_in @seller
    old_slug = @store.slug

    patch seller_store_path, params: { store: { name: "Falcon Hardware" } }

    assert_redirected_to edit_seller_store_path(locale: :es)
    @store.reload
    assert_equal "falcon-hardware", @store.slug

    get "/es/s/#{old_slug}"
    assert_redirected_to store_path(@store, locale: :es, tab: nil)
    assert_response :moved_permanently
  end

  test "store profile rejects a short name" do
    sign_in @seller

    patch seller_store_path, params: { store: { name: "ab" } }

    assert_response :unprocessable_entity
    assert_match I18n.t("activerecord.attributes.store.name"), response.body
  end

  test "professional stores require a valid Spanish tax id" do
    sign_in @seller

    patch seller_store_path, params: {
      store: { name: @store.name, store_type: "professional", company_name: "Falcon SL", tax_id: "B12345670" }
    }

    assert_response :unprocessable_entity
    assert_match I18n.t("activerecord.errors.models.store.attributes.tax_id.invalid"), response.body

    patch seller_store_path, params: {
      store: { name: @store.name, store_type: "professional", company_name: "Falcon SL", tax_id: "B12345674" }
    }
    assert_redirected_to edit_seller_store_path(locale: :es)
  end

  test "updates store policies" do
    sign_in @seller

    patch seller_store_policy_path, params: {
      store: { return_policy: "30 days", shipping_policy: "24 hours", allow_offers_default: "0" }
    }

    assert_redirected_to edit_seller_store_policy_path(locale: :es)
    @store.reload
    assert_equal "30 days", @store.return_policy
    assert_not @store.allow_offers_default
  end

  test "vacation mode disables adding listings to the cart" do
    sign_in @seller
    patch seller_vacation_path, params: { store: { vacation_mode: "1", vacation_message: "Back soon" } }
    assert @store.reload.on_vacation?

    sign_out @seller
    sign_in users(:buyer)

    assert_no_difference -> { CartItem.count } do
      post cart_items_path(listing_id: @listing.id)
    end

    assert_match I18n.t("cart.errors.vacation"), flash[:alert].to_s
  end

  test "listing page shows the vacation notice" do
    @store.update!(vacation_mode: true, vacation_message: "Back soon")

    get "/es/l/#{@listing.slug}"

    assert_response :success
    assert_match "Back soon", response.body
    assert_select "button[disabled]"
  end

  test "payouts page explains the current payment model" do
    sign_in @seller

    get seller_payout_path

    assert_response :success
    assert_match I18n.t("seller.payouts.not_connected"), response.body
    assert_select "button[disabled]", text: I18n.t("seller.payouts.connect")
  end

  test "sales index renders an empty state" do
    user = User.create!(
      email: "no-sales@example.com", password: "Password123!",
      username: "No-Sales#1", country_code: "ES", confirmed_at: Time.current,
      terms_accepted_at: Time.current
    )
    sign_in user

    get seller_orders_path

    assert_response :success
    assert_match I18n.t("seller.orders.empty_title"), response.body
  end
end
