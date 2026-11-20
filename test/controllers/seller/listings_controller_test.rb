require "test_helper"

class Seller::ListingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:confirmed)
    @store = stores(:confirmed_store)
    sign_in @user
    # Warden's test-mode sign_in only injects the user into the *next* request;
    # warm the session up with one successful request first (same trick as the
    # stores tests).
    get "/en/seller/listings"
    assert_response :success
  end

  def listing_params(overrides = {})
    { listing: {
      category_id: categories(:gpus).id,
      title: "Gigabyte RTX 4070 Aorus Master 12 GB",
      description: "Barely used, original box and invoice included.",
      price: "499.99",
      original_price: "",
      quantity: "1",
      condition: "used_like_new",
      shipping_method: "own_label",
      shipping_price: "",
      free_shipping: "1",
      ships_within_days: "2",
      local_pickup: "0",
      province: "",
      city: "Madrid",
      postal_code: "",
      allow_offers: "1"
    }.merge(overrides) }
  end

  # A second, store-less seller. Must be confirmed — Devise's confirmable
  # rejects sign_in for unconfirmed users (the :pending fixture won't sign in).
  def storeless_seller
    @storeless_seller ||= User.create!(
      email: "seller-two@example.com", username: "sellertwo",
      password: "password123", confirmed_at: Time.current
    )
  end

  # --- Authentication ---------------------------------------------------------

  test "requires a signed-in user" do
    sign_out @user

    get "/en/seller/listings"
    assert_redirected_to "/en/users/sign_in"

    get "/en/seller/listings/new"
    assert_redirected_to "/en/users/sign_in"

    post "/en/seller/listings", params: listing_params
    assert_redirected_to "/en/users/sign_in"
  end

  # --- New --------------------------------------------------------------------

  test "new renders the sell form with the basic sections" do
    get "/en/seller/listings/new"

    assert_response :success
    assert_select "form[action=?]", "/en/seller/listings"
    assert_select "select[name=?]", "listing[category_id]"
    assert_select "input[name=?][type=radio]", "listing[condition]", Listing.conditions.size
    assert_select "input[name=?][type=radio]", "listing[shipping_method]", Listing.shipping_methods.size
    assert_select "select[name=?]", "listing[province]"
    assert_select "input[name=?]", "listing[price]"
    assert_select "input[name=?]", "listing[allow_offers]"
  end

  test "new prefills location and offer defaults from the store" do
    @store.update_columns(allow_offers_default: false, city: "Barcelona",
                          province: "08", postal_code: "08001")

    get "/en/seller/listings/new"

    assert_response :success
    assert_select "input[name=?][value=?]", "listing[city]", "Barcelona"
    assert_select "input[name=?][value=?]", "listing[postal_code]", "08001"
    assert_select "input[type=checkbox][name=?][checked]", "listing[allow_offers]", 0
  end

  test "a seller without a store gets one created on new" do
    other = storeless_seller
    sign_out @user
    sign_in other

    get "/en/seller/listings/new"

    assert_response :success
    assert_not_nil other.reload.store
  end

  # --- Create -------------------------------------------------------------------

  test "create saves a draft and converts euro amounts to cents" do
    assert_difference "Listing.count", 1 do
      post "/en/seller/listings", params: listing_params
    end

    listing = @store.listings.find_by(title: "Gigabyte RTX 4070 Aorus Master 12 GB")
    assert_redirected_to "/en/seller/listings/#{listing.to_param}/edit"
    assert_predicate listing, :draft?
    assert_equal 49_999, listing.price_cents
    assert_equal 0, listing.shipping_price_cents
    assert_predicate listing, :free_shipping?
    assert_equal "used_like_new", listing.condition
    assert_equal "Madrid", listing.city
  end

  test "create re-renders the form with 422 on invalid input" do
    assert_no_difference "Listing.count" do
      post "/en/seller/listings", params: listing_params(title: "A")
    end

    assert_response :unprocessable_entity
    assert_select "form[action=?] input[name=?]", "/en/seller/listings", "listing[title]"
  end

  test "create rejects a price that is not a number with 422" do
    # The virtual euro writer turns garbage into nil, so the presence
    # validation surfaces it instead of a type error.
    assert_no_difference "Listing.count" do
      post "/en/seller/listings", params: listing_params(price: "lots")
    end

    assert_response :unprocessable_entity
  end

  test "create lazily creates the store for a first-time seller" do
    other = storeless_seller
    sign_out @user
    sign_in other
    get "/en/seller/listings/new" # warm the session up

    post "/en/seller/listings", params: listing_params(title: "My First Listing")

    store = other.reload.store
    assert_not_nil store
    listing = store.listings.find_by(title: "My First Listing")
    assert_not_nil listing
    assert_redirected_to "/en/seller/listings/#{listing.to_param}/edit"
  end

  # --- Edit / update --------------------------------------------------------------

  test "edit renders the seller's own listing prefilled" do
    listing = create_listing(title: "MSI RTX 3070 Ventus 8 GB", price_cents: 32_000)

    get "/en/seller/listings/#{listing.to_param}/edit"

    assert_response :success
    assert_select "form[action=?]", "/en/seller/listings/#{listing.to_param}"
    assert_select "input[name=?][value=?]", "listing[title]", "MSI RTX 3070 Ventus 8 GB"
    assert_select "input[name=?][value=?]", "listing[price]", "320.0"
  end

  test "update saves changes" do
    listing = create_listing(title: "ASUS TUF Gaming B650 Board")

    patch "/en/seller/listings/#{listing.to_param}", params: listing_params(
      title: "ASUS TUF Gaming B650-Plus Board", price: "189.90"
    )

    assert_redirected_to "/en/seller/listings/#{listing.to_param}/edit"
    listing.reload
    assert_equal "ASUS TUF Gaming B650-Plus Board", listing.title
    assert_equal 18_990, listing.price_cents
  end

  test "update re-renders the form with 422 on invalid input" do
    listing = create_listing(title: "Corsair RM750x Power Supply")

    patch "/en/seller/listings/#{listing.to_param}", params: listing_params(price: "")

    assert_response :unprocessable_entity
    assert_equal 50_000, listing.reload.price_cents
  end

  test "editing a published listing sends it back to pending review" do
    listing = publish(create_listing(title: "Zotac RTX 4060 Twin Edge 8 GB"))

    patch "/en/seller/listings/#{listing.to_param}",
      params: listing_params(title: "Zotac RTX 4060 Twin Edge 8 GB OC")

    assert_redirected_to "/en/seller/listings/#{listing.to_param}/edit"
    assert_predicate listing.reload, :pending_review?
  end

  # --- Ownership --------------------------------------------------------------------

  test "another seller's listing is a 404 on every member route" do
    foreign_store = Store.create!(user: users(:pending), name: "Other Seller Shop")
    foreign = create_listing(store: foreign_store, title: "Someone Else's Graphics Card")

    get "/en/seller/listings/#{foreign.to_param}/edit"
    assert_response :not_found

    patch "/en/seller/listings/#{foreign.to_param}", params: listing_params(title: "Hijacked Listing Title")
    assert_response :not_found

    delete "/en/seller/listings/#{foreign.to_param}"
    assert_response :not_found

    assert_equal "Someone Else's Graphics Card", foreign.reload.title
    assert_predicate foreign, :draft?
  end

  test "a seller without a store sees an empty index" do
    other = storeless_seller
    sign_out @user
    sign_in other

    get "/en/seller/listings"

    assert_response :success
  end

  # --- Destroy ------------------------------------------------------------------------

  test "destroy deletes a draft for good" do
    listing = create_listing(title: "Kingston Fury Beast 32 GB DDR5")

    assert_difference "Listing.count", -1 do
      delete "/en/seller/listings/#{listing.to_param}"
    end

    assert_redirected_to "/en/seller/listings"
  end

  test "destroy deletes a rejected listing for good" do
    listing = create_listing(title: "Noisy Blower Cooler Clearance")
    listing.submit!
    listing.reject!

    assert_difference "Listing.count", -1 do
      delete "/en/seller/listings/#{listing.to_param}"
    end

    assert_redirected_to "/en/seller/listings"
  end

  test "destroy archives a listing that has been published" do
    listing = publish(create_listing(title: "Samsung 990 Pro 2 TB NVMe"))

    assert_no_difference "Listing.count" do
      delete "/en/seller/listings/#{listing.to_param}"
    end

    assert_redirected_to "/en/seller/listings"
    assert_predicate listing.reload, :archived?
  end

  # --- Index ------------------------------------------------------------------------

  test "index filters by status and shows per-status counts" do
    create_listing(title: "Draft Graphics Card One")
    create_listing(title: "Draft Graphics Card Two")
    publish(create_listing(title: "Published Graphics Card"))

    get "/en/seller/listings"
    assert_response :success
    assert_select "a[href=?]", "/en/seller/listings?status=draft" do
      assert_select "span", text: "2"
    end
    assert_select "a[href=?]", "/en/seller/listings?status=published" do
      assert_select "span", text: "1"
    end
    assert_select "a[href=?]", "/en/seller/listings?status=archived" do
      assert_select "span", text: "0"
    end
    # Default tab is drafts — the published one must not leak in.
    assert_select "li a", text: "Draft Graphics Card One"
    assert_select "li a", text: "Published Graphics Card", count: 0

    get "/en/seller/listings?status=published"
    assert_response :success
    assert_select "li a", text: "Published Graphics Card"
    assert_select "li a", text: "Draft Graphics Card One", count: 0
  end

  test "index shows the rejection reason on rejected listings" do
    listing = create_listing(title: "Counterfeit Looking RAM")
    listing.submit!
    listing.reject!
    listing.update!(rejection_reason: "Photos do not match the item.")

    get "/en/seller/listings?status=rejected"

    assert_response :success
    assert_select "li", text: /Photos do not match the item\./
  end

  test "index falls back to drafts on an unknown status" do
    get "/en/seller/listings?status=bogus"

    assert_response :success
    assert_select "a[href=?][aria-current=page]", "/en/seller/listings?status=draft"
  end
end
