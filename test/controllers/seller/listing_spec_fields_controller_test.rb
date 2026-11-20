require "test_helper"

class Seller::ListingSpecFieldsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:confirmed)
    @store = stores(:confirmed_store)
    sign_in @user
    # Warm up Warden's test session (same trick as the listings tests).
    get "/en/seller/listings"
    assert_response :success
  end

  def fields_url(category: categories(:gpus), listing: nil)
    url = "/en/seller/listing_spec_fields?category_id=#{category.id}"
    listing ? "#{url}&listing_id=#{listing.id}" : url
  end

  # --- Authentication ---------------------------------------------------------

  test "requires a signed-in user" do
    sign_out @user

    get fields_url
    assert_redirected_to "/en/users/sign_in"
  end

  # --- Rendering ------------------------------------------------------------------

  test "renders the form fields for the category, inherited filters included" do
    # console_platform is the fixtures' only single_select definition.
    CategoryFilter.create!(category: categories(:gpus),
                           filter_definition: filter_definitions(:console_platform))

    get fields_url

    assert_response :success
    assert_select "turbo-frame#listing_specs"
    # gpu_chipset + rgb_lighting are inherited from components, cpu_brand is
    # gpus' own definition.
    assert_select "input[type=checkbox][name=?]", "listing[specs][gpu_chipset][]", 2
    assert_select "select[name=?]", "listing[specs][cpu_brand]", count: 0
    assert_select "select[name=?]", "listing[specs][console_platform]"
    assert_select "input[type=checkbox][name=?][value=true]", "listing[specs][rgb_lighting]"
    # The inactive "intel" gpu_chipset option must not render.
    assert_select "input[type=checkbox][name=?][value=intel]", "listing[specs][gpu_chipset][]", 0
  end

  test "options render featured first" do
    get fields_url

    assert_select "input[type=checkbox][name=?]", "listing[specs][gpu_chipset][]" do |inputs|
      assert_equal "nvidia", inputs.first["value"] # nvidia is the featured option
    end
  end

  test "renders a prompt without a category" do
    get "/en/seller/listing_spec_fields"

    assert_response :success
    assert_select "turbo-frame#listing_specs", text: /Choose a category first/
  end

  # --- Current values ---------------------------------------------------------------

  test "prefills the values of the seller's own listing" do
    listing = create_listing(specs: { "gpu_chipset" => [ "nvidia" ], "rgb_lighting" => true })

    get fields_url(listing: listing)

    assert_response :success
    assert_select "input[type=checkbox][name=?][value=nvidia][checked]", "listing[specs][gpu_chipset][]"
    assert_select "input[type=checkbox][name=?][value=true][checked]", "listing[specs][rgb_lighting]"
  end

  test "another seller's listing id is a 404" do
    foreign_store = Store.create!(user: users(:pending), name: "Other Seller Shop")
    foreign = create_listing(store: foreign_store, title: "Someone Else's Graphics Card",
                             specs: { "gpu_chipset" => [ "nvidia" ] })

    get fields_url(listing: foreign)

    assert_response :not_found
  end
end
