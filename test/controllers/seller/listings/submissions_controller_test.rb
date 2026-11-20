require "test_helper"

class Seller::Listings::SubmissionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:confirmed)
    @store = stores(:confirmed_store)
    sign_in @user
    # Warm up the Warden session (see Seller::ListingsControllerTest).
    get "/en/seller/listings"
    assert_response :success
  end

  # --- Create (submit for review) -------------------------------------------

  test "submitting a complete draft sends it to pending review" do
    listing = create_listing
    attach_photo(listing)

    post "/en/seller/listings/#{listing.to_param}/submission"

    assert_redirected_to "/en/seller/listings"
    assert_predicate listing.reload, :pending_review?
    assert_equal "Listing submitted for review.", flash[:notice]
  end

  test "submitting a draft without photos fails with the image error" do
    listing = create_listing

    post "/en/seller/listings/#{listing.to_param}/submission"

    assert_redirected_to "/en/seller/listings/#{listing.to_param}/edit"
    assert_predicate listing.reload, :draft?
    assert_equal I18n.t("errors.messages.image_required_for_review"), flash[:alert]
  end

  test "submitting a draft with missing required specs lists the messages" do
    memory = FilterDefinition.create!(key: "gpu_memory", input_type: :single_select,
                                      required_in_form: true, position: 4,
                                      label_translations: { "en": "Memory" },
                                      group_translations: { "en": "Graphics" })
    memory.filter_options.create!(value: "8gb", label_translations: { "en": "8 GB" })
    CategoryFilter.create!(category: categories(:gpus), filter_definition: memory)

    listing = create_listing(specs: { "gpu_chipset" => [ "nvidia" ] })
    attach_photo(listing)

    post "/en/seller/listings/#{listing.to_param}/submission"

    assert_redirected_to "/en/seller/listings/#{listing.to_param}/edit"
    assert_predicate listing.reload, :draft?
    assert_includes flash[:alert], "Memory"
  end

  test "submitting a rejected listing sends it back to review" do
    listing = create_listing
    attach_photo(listing)
    listing.submit!
    listing.reject!

    post "/en/seller/listings/#{listing.to_param}/submission"

    assert_redirected_to "/en/seller/listings"
    assert_predicate listing.reload, :pending_review?
  end

  test "with listing_auto_approve on, submitting publishes straight away" do
    set_setting("listing_auto_approve", true)
    listing = create_listing
    attach_photo(listing)

    post "/en/seller/listings/#{listing.to_param}/submission"

    assert_redirected_to "/en/seller/listings"
    assert_predicate listing.reload, :published?
  end

  test "submitting a listing that is already published is refused" do
    listing = publish(create_listing)

    post "/en/seller/listings/#{listing.to_param}/submission"

    assert_redirected_to "/en/seller/listings"
    assert_predicate listing.reload, :published?
    assert_equal I18n.t("seller.listings.invalid_transition"), flash[:alert]
  end

  test "turbo gets the refreshed row and the toast" do
    listing = create_listing
    attach_photo(listing)

    post "/en/seller/listings/#{listing.to_param}/submission",
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action=?][target=?]", "replace", dom_id(listing)
    assert_select "turbo-stream[action=?][target=?]", "replace", "toasts"
    assert_includes response.body, "Listing submitted for review."
    assert_predicate listing.reload, :pending_review?
  end

  test "another seller's listing 404s" do
    other_store = Store.create!(user: users(:pending), name: "Other Seller Shop")
    listing = create_listing(store: other_store)

    post "/en/seller/listings/#{listing.to_param}/submission"

    assert_response :not_found
    assert_predicate listing.reload, :draft?
  end

  test "requires a signed-in user" do
    sign_out @user

    post "/en/seller/listings/1/submission"

    assert_redirected_to "/en/users/sign_in"
  end
end
