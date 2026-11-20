require "test_helper"

class Seller::Listings::SalesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:confirmed)
    @store = stores(:confirmed_store)
    sign_in @user
    # Warm up the Warden session (see Seller::ListingsControllerTest).
    get "/en/seller/listings"
    assert_response :success
  end

  test "marking a single-stock listing as sold stamps sold_at" do
    listing = publish(create_listing)

    post "/en/seller/listings/#{listing.to_param}/sale"

    assert_redirected_to "/en/seller/listings"
    listing.reload
    assert_predicate listing, :sold?
    assert_not_nil listing.sold_at
    assert_equal "Listing marked as sold.", flash[:notice]
  end

  test "a paused listing can be marked as sold too" do
    listing = publish(create_listing)
    listing.pause!

    post "/en/seller/listings/#{listing.to_param}/sale"

    assert_redirected_to "/en/seller/listings"
    assert_predicate listing.reload, :sold?
  end

  test "marking as sold on a multi-stock listing only uses one unit" do
    listing = publish(create_listing(quantity: 3))

    post "/en/seller/listings/#{listing.to_param}/sale"

    assert_redirected_to "/en/seller/listings"
    listing.reload
    assert_equal 2, listing.quantity
    assert_predicate listing, :published?
    assert_nil listing.sold_at
    assert_equal "Sale recorded — 2 left in stock.", flash[:notice]
  end

  test "selling a draft is refused with a friendly alert" do
    listing = create_listing

    post "/en/seller/listings/#{listing.to_param}/sale"

    assert_redirected_to "/en/seller/listings"
    assert_predicate listing.reload, :draft?
    assert_equal I18n.t("seller.listings.invalid_transition"), flash[:alert]
  end

  test "turbo gets the refreshed row" do
    listing = publish(create_listing)

    post "/en/seller/listings/#{listing.to_param}/sale",
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_select "turbo-stream[action=?][target=?]", "replace", dom_id(listing)
    assert_includes response.body, "Listing marked as sold."
    assert_predicate listing.reload, :sold?
  end

  test "another seller's listing 404s" do
    other_store = Store.create!(user: users(:pending), name: "Other Seller Shop")
    listing = publish(create_listing(store: other_store))

    post "/en/seller/listings/#{listing.to_param}/sale"

    assert_response :not_found
    assert_predicate listing.reload, :published?
  end

  test "requires a signed-in user" do
    sign_out @user

    post "/en/seller/listings/1/sale"

    assert_redirected_to "/en/users/sign_in"
  end
end
