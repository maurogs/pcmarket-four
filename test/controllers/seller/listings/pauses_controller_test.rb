require "test_helper"

class Seller::Listings::PausesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:confirmed)
    @store = stores(:confirmed_store)
    sign_in @user
    # Warm up the Warden session (see Seller::ListingsControllerTest).
    get "/en/seller/listings"
    assert_response :success
  end

  # --- Create (pause) ---------------------------------------------------------

  test "pausing a published listing hides it" do
    listing = publish(create_listing)

    post "/en/seller/listings/#{listing.to_param}/pause"

    assert_redirected_to "/en/seller/listings"
    assert_predicate listing.reload, :paused?
    assert_equal "Listing paused.", flash[:notice]
  end

  test "pausing a draft is refused with a friendly alert" do
    listing = create_listing

    post "/en/seller/listings/#{listing.to_param}/pause"

    assert_redirected_to "/en/seller/listings"
    assert_predicate listing.reload, :draft?
    assert_equal I18n.t("seller.listings.invalid_transition"), flash[:alert]
  end

  # --- Destroy (resume) -------------------------------------------------------

  test "resuming a paused listing publishes it again" do
    listing = publish(create_listing)
    listing.pause!

    delete "/en/seller/listings/#{listing.to_param}/pause"

    assert_redirected_to "/en/seller/listings"
    assert_predicate listing.reload, :published?
    assert_equal "Listing is published again.", flash[:notice]
  end

  test "resuming a published listing is refused" do
    listing = publish(create_listing)

    delete "/en/seller/listings/#{listing.to_param}/pause"

    assert_redirected_to "/en/seller/listings"
    assert_predicate listing.reload, :published?
    assert_equal I18n.t("seller.listings.invalid_transition"), flash[:alert]
  end

  test "turbo gets the refreshed row" do
    listing = publish(create_listing)

    post "/en/seller/listings/#{listing.to_param}/pause",
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_select "turbo-stream[action=?][target=?]", "replace", dom_id(listing)
    assert_select "turbo-stream[action=?][target=?]", "replace", "toasts"
    assert_includes response.body, "Listing paused."
    assert_predicate listing.reload, :paused?
  end

  test "another seller's listing 404s" do
    other_store = Store.create!(user: users(:pending), name: "Other Seller Shop")
    listing = publish(create_listing(store: other_store))

    post "/en/seller/listings/#{listing.to_param}/pause"

    assert_response :not_found
    assert_predicate listing.reload, :published?
  end

  test "requires a signed-in user" do
    sign_out @user

    post "/en/seller/listings/1/pause"

    assert_redirected_to "/en/users/sign_in"
  end
end
