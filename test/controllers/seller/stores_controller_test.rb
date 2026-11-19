require "test_helper"

class Seller::StoresControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:confirmed)
    @store = stores(:confirmed_store)
    sign_in @user
    # Warden's test-mode sign_in only injects the user into the *next* request;
    # warm the session up with one successful request first (same trick as the
    # account tests).
    get "/en/seller/store/edit"
    assert_response :success
  end

  def store_params(overrides = {})
    { store: {
      name: "Confirmed Store",
      bio: "",
      kind: "individual",
      business_name: "",
      tax_id: "",
      vacation_mode: "0",
      vacation_message: "",
      allow_offers_default: "1",
      city: "",
      province: "",
      postal_code: ""
    }.merge(overrides) }
  end

  def upload(content, content_type, filename)
    Rack::Test::UploadedFile.new(StringIO.new(content), content_type, original_filename: filename)
  end

  # A second, store-less seller. Must be confirmed — Devise's confirmable
  # rejects sign_in for unconfirmed users (the :pending fixture won't sign in).
  def new_seller
    @new_seller ||= User.create!(
      email: "seller-two@example.com", username: "sellertwo",
      password: "password123", confirmed_at: Time.current
    )
  end

  # --- Authentication -----------------------------------------------------------

  test "requires a signed-in user" do
    sign_out @user

    get "/en/seller/store/new"
    assert_redirected_to "/en/users/sign_in"

    get "/en/seller/store/edit"
    assert_redirected_to "/en/users/sign_in"

    post "/en/seller/store", params: store_params
    assert_redirected_to "/en/users/sign_in"

    patch "/en/seller/store", params: store_params
    assert_redirected_to "/en/users/sign_in"
  end

  # --- Opening a store ----------------------------------------------------------

  test "new redirects to the settings page when the user already has a store" do
    get "/en/seller/store/new"

    assert_redirected_to "/en/seller/store/edit"
  end

  test "a user without a store can open exactly one" do
    other = new_seller
    sign_out @user
    sign_in other

    get "/en/seller/store/new"
    assert_response :success
    assert_select "form[action=?]", "/en/seller/store"

    post "/en/seller/store", params: store_params(name: "Pending Corner")

    assert_redirected_to "/en/seller/store/edit"
    store = other.reload.store
    assert_not_nil store
    assert_equal "Pending Corner", store.name
    assert_equal "pending-corner", store.slug

    # Opening again bounces to the settings page — one store per user.
    get "/en/seller/store/new"
    assert_redirected_to "/en/seller/store/edit"
    assert_equal 1, Store.where(user: other).count
  end

  test "create re-renders the form with 422 on invalid input" do
    other = new_seller
    sign_out @user
    sign_in other
    get "/en/seller/store/new" # warm the session up

    post "/en/seller/store", params: store_params(name: "A")

    assert_response :unprocessable_entity
    assert_select "form[action=?] input[name=?]", "/en/seller/store", "store[name]"
    assert_nil other.reload.store
  end

  # --- Edit ---------------------------------------------------------------------

  test "edit renders the settings form prefilled" do
    assert_select "form[action=?][enctype=?]", "/en/seller/store", "multipart/form-data"
    assert_select "input[name=?][value=?]", "store[name]", "Confirmed Store"
    assert_select "input[type=radio][name=?][value=?]", "store[kind]", "individual"
    assert_select "select[name=?]", "store[province]"
    assert_select "input[type=checkbox][name=?]", "store[vacation_mode]"
    assert_select "input[type=checkbox][name=?]", "store[allow_offers_default]"
  end

  # --- Update -------------------------------------------------------------------

  test "update saves settings and re-slugs a renamed store" do
    patch "/en/seller/store", params: store_params(
      name: "Retro Corner",
      bio: "Vintage GPUs and retro keyboards.",
      city: "Madrid",
      province: "28",
      postal_code: "28001"
    )

    assert_redirected_to "/en/seller/store/edit"
    @store.reload
    assert_equal "Retro Corner", @store.name
    assert_equal "retro-corner", @store.slug
    assert_equal "Vintage GPUs and retro keyboards.", @store.bio
    assert_equal "Madrid", @store.city
    assert_equal "28", @store.province
    assert_equal "28001", @store.postal_code
  end

  test "update rejects a name that is too short with 422" do
    patch "/en/seller/store", params: store_params(name: "A")

    assert_response :unprocessable_entity
    assert_equal "Confirmed Store", @store.reload.name
  end

  test "update rejects a name taken by another store regardless of case" do
    Store.create!(user: users(:pending), name: "Other Seller Shop")

    patch "/en/seller/store", params: store_params(name: "other seller shop")

    assert_response :unprocessable_entity
    assert_equal "Confirmed Store", @store.reload.name
  end

  test "update requires business identity when switching to business" do
    patch "/en/seller/store", params: store_params(kind: "business")

    assert_response :unprocessable_entity
    assert_not_predicate @store.reload, :business?
  end

  test "update rejects a malformed Spanish tax id with 422" do
    patch "/en/seller/store", params: store_params(
      kind: "business",
      business_name: "Retro Corner S.L.",
      tax_id: "12345678A"
    )

    assert_response :unprocessable_entity
    @store.reload
    assert_not_predicate @store, :business?
    assert_nil @store.tax_id
  end

  test "update accepts a valid business identity" do
    patch "/en/seller/store", params: store_params(
      kind: "business",
      business_name: "Retro Corner S.L.",
      tax_id: "b12345678"
    )

    assert_redirected_to "/en/seller/store/edit"
    @store.reload
    assert_predicate @store, :business?
    assert_equal "B12345678", @store.tax_id
  end

  test "update toggles vacation mode on and off" do
    patch "/en/seller/store", params: store_params(
      vacation_mode: "1",
      vacation_message: "Back in December!"
    )

    assert_redirected_to "/en/seller/store/edit"
    @store.reload
    assert_predicate @store, :vacation_mode?
    assert_equal "Back in December!", @store.vacation_message

    patch "/en/seller/store", params: store_params(vacation_mode: "0")

    assert_not_predicate @store.reload, :vacation_mode?
  end

  test "update attaches a valid logo" do
    patch "/en/seller/store", params: store_params(
      logo: upload("fake png bytes", "image/png", "logo.png")
    )

    assert_redirected_to "/en/seller/store/edit"
    assert_predicate @store.reload.logo, :attached?
  end

  test "update rejects an oversized banner with 422" do
    big = upload("x" * (8.megabytes + 1), "image/png", "banner.png")

    patch "/en/seller/store", params: store_params(banner: big)

    assert_response :unprocessable_entity
    assert_not_predicate @store.reload.banner, :attached?
  end

  test "update rejects a non-image logo with 422" do
    patch "/en/seller/store", params: store_params(
      logo: upload("not an image", "text/plain", "notes.txt")
    )

    assert_response :unprocessable_entity
    assert_not_predicate @store.reload.logo, :attached?
  end

  test "update removes attachments when the remove flags are checked" do
    @store.logo.attach(io: StringIO.new("fake png bytes"), filename: "logo.png", content_type: "image/png")
    @store.banner.attach(io: StringIO.new("fake png bytes"), filename: "banner.png", content_type: "image/png")

    patch "/en/seller/store", params: store_params(remove_logo: "1", remove_banner: "1")

    assert_redirected_to "/en/seller/store/edit"
    @store.reload
    assert_not_predicate @store.logo, :attached?
    assert_not_predicate @store.banner, :attached?
  end

  # --- Ownership ------------------------------------------------------------------

  test "a seller without a store is sent to the opening flow" do
    other = new_seller
    sign_out @user
    sign_in other

    get "/en/seller/store/edit"
    assert_redirected_to "/en/seller/store/new"
  end

  test "sellers only ever see and change their own store" do
    other = new_seller
    sign_out @user
    sign_in other
    get "/en/seller/store/new" # warm the session up

    # The singular routes never address another store by id.
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/en/seller/store/#{@store.id}", method: :patch)
    end

    patch "/en/seller/store", params: store_params(name: "Stolen Identity")
    assert_redirected_to "/en/seller/store/new"
    assert_equal "Confirmed Store", @store.reload.name

    post "/en/seller/store", params: store_params(name: "Pending Corner")
    assert_redirected_to "/en/seller/store/edit"

    get "/en/seller/store/edit"
    assert_response :success
    assert_select "input[name=?][value=?]", "store[name]", "Pending Corner"
    assert_select "input[name=?][value=?]", "store[name]", "Confirmed Store", 0
  end
end
