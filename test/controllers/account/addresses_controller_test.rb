require "test_helper"

class Account::AddressesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:confirmed)
    sign_in @user
    # Warden's test-mode sign_in only injects the user into the *next* request;
    # a 404 rendered by the exceptions app drops that response's session
    # cookie. Warm the session up with one successful request first.
    get "/en/account/addresses"
    assert_response :success
  end

  def address_params(overrides = {})
    { address: {
      label: "Home",
      first_name: "Ana",
      last_name: "García",
      company: "",
      street_line1: "Calle Mayor 1",
      street_line2: "",
      city: "Madrid",
      province: "28",
      postal_code: "28001",
      country_id: countries(:es).id,
      phone: "",
      default_shipping: "0"
    }.merge(overrides) }
  end

  def create_address(user: @user, **overrides)
    user.addresses.create!({
      country: countries(:es), first_name: "Ana", last_name: "García",
      street_line1: "Calle Mayor 1", city: "Madrid", province: "28",
      postal_code: "28001"
    }.merge(overrides))
  end

  # --- Authentication -----------------------------------------------------------

  test "requires a signed-in user" do
    sign_out @user

    get "/en/account/addresses"
    assert_response :redirect
    assert_redirected_to "/en/users/sign_in"

    post "/en/account/addresses", params: address_params
    assert_response :redirect
    assert_redirected_to "/en/users/sign_in"
  end

  # --- Index --------------------------------------------------------------------

  test "index lists own addresses and hides other users' ones" do
    mine = create_address(street_line1: "Mi Calle 3")
    theirs = create_address(user: users(:pending), street_line1: "Su Calle 99")

    get "/en/account/addresses"

    assert_response :success
    assert_match "Mi Calle 3", response.body
    assert_no_match "Su Calle 99", response.body
    assert_select "a[href=?]", "/en/account/addresses/#{mine.id}/edit"
    assert_select "a[href=?]", "/en/account/addresses/#{theirs.id}/edit", 0
  end

  test "index shows the empty state without addresses" do
    get "/en/account/addresses"

    assert_response :success
    assert_select "p.text-muted", text: I18n.t("account.addresses.index.empty", locale: :en)
  end

  # --- New / create ---------------------------------------------------------------

  test "new renders the form with enabled countries and Spanish provinces" do
    get "/en/account/addresses/new"

    assert_response :success
    assert_select "form[action=?]", "/en/account/addresses"
    assert_select "select[name=?] option[value=?]", "address[country_id]", countries(:es).id.to_s
    # FR exists but is disabled — it must not be offered.
    assert_select "select[name=?] option[value=?]", "address[country_id]", countries(:fr).id.to_s, 0
    assert_select "select[name=?] option[value=?]", "address[province]", "28"
  end

  test "create saves the address and makes the first one the default" do
    assert_difference "@user.addresses.count" do
      post "/en/account/addresses", params: address_params
    end

    address = @user.addresses.reload.last
    assert_redirected_to "/en/account/addresses"
    assert_equal "Home", address.label
    assert_predicate address, :default_shipping?
  end

  test "create with default_shipping on moves the default from the previous address" do
    first = create_address

    post "/en/account/addresses", params: address_params(default_shipping: "1")

    assert_predicate @user.addresses.reload.last, :default_shipping?
    assert_not_predicate first.reload, :default_shipping?
  end

  test "create re-renders the form with 422 on invalid input" do
    assert_no_difference "Address.count" do
      post "/en/account/addresses", params: address_params(postal_code: "2801", province: "")
    end

    assert_response :unprocessable_entity
    assert_select "form[action=?] input[name=?]", "/en/account/addresses", "address[postal_code]"
  end

  # --- Edit / update --------------------------------------------------------------

  test "edit renders the prefilled form" do
    address = create_address(label: "Home")

    get "/en/account/addresses/#{address.id}/edit"

    assert_response :success
    assert_select "form[action=?][method=?]", "/en/account/addresses/#{address.id}", "post"
    assert_select "input[name=?][value=?]", "address[street_line1]", "Calle Mayor 1"
  end

  test "update saves changes" do
    address = create_address

    patch "/en/account/addresses/#{address.id}",
      params: address_params(street_line1: "Nueva Calle 5", label: "Office")

    assert_redirected_to "/en/account/addresses"
    assert_equal "Nueva Calle 5", address.reload.street_line1
    assert_equal "Office", address.label
  end

  test "update re-renders the form with 422 on invalid input" do
    address = create_address

    patch "/en/account/addresses/#{address.id}", params: address_params(city: "")

    assert_response :unprocessable_entity
    assert_equal "Calle Mayor 1", address.reload.street_line1
  end

  # --- Destroy --------------------------------------------------------------------

  test "destroy removes the address" do
    address = create_address

    assert_difference "Address.count", -1 do
      delete "/en/account/addresses/#{address.id}"
    end

    assert_redirected_to "/en/account/addresses"
  end

  # --- Scoping (other users' addresses 404) ----------------------------------------

  test "cannot read, update or destroy another user's address" do
    theirs = create_address(user: users(:pending))

    get "/en/account/addresses/#{theirs.id}/edit"
    assert_response :not_found

    patch "/en/account/addresses/#{theirs.id}", params: address_params(street_line1: "Hack 1")
    assert_response :not_found

    delete "/en/account/addresses/#{theirs.id}"
    assert_response :not_found

    assert_equal "Calle Mayor 1", theirs.reload.street_line1
  end

  # --- Default (nested singular resource) ------------------------------------------

  test "PATCH default makes the address the user's default" do
    first = create_address
    second = create_address(label: "Office", street_line1: "Otra 2")

    patch "/en/account/addresses/#{second.id}/default"

    assert_redirected_to "/en/account/addresses"
    assert_predicate second.reload, :default_shipping?
    assert_not_predicate first.reload, :default_shipping?
  end

  test "PATCH default 404s for another user's address" do
    pending = users(:pending)
    pending.addresses.create!(country: countries(:es), first_name: "Otra", last_name: "Persona",
      street_line1: "Primera 1", city: "Barcelona", province: "08", postal_code: "08001")
    theirs = create_address(user: pending, street_line1: "Segunda 2")
    assert_not_predicate theirs, :default_shipping?

    patch "/en/account/addresses/#{theirs.id}/default"

    assert_response :not_found
    assert_not_predicate theirs.reload, :default_shipping?
  end

  test "default update requires a signed-in user" do
    address = create_address
    sign_out @user

    patch "/en/account/addresses/#{address.id}/default"

    assert_redirected_to "/en/users/sign_in"
  end
end
