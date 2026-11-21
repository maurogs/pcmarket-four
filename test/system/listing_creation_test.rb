require "application_system_test_case"

class ListingCreationTest < ApplicationSystemTestCase
  setup do
    @seller = users(:seller)
    visit "/en/users/sign_in"
    fill_in "user_email", with: @seller.email
    fill_in "user_password", with: "Password123!"
    click_button I18n.t("auth.sign_in.submit", locale: :en)
    assert_selector "a[href='/en/seller/listings']", visible: :all
  end

  teardown do
    page.driver.browser.execute_cdp("Network.clearBrowserCookies")
  end

  test "seller creates and submits a listing end to end" do
    visit new_listing_path(locale: :en)

    within("#section-category") do
      find("summary", text: "Components").click
      find("a", text: "Graphics cards").execute_script("this.click()")
    end
    assert_selector "select[name='listing[specs][cpu_brand]']"
    assert_selector "input[name='listing[category_id]'][value='#{categories(:graphics_cards).id}']", visible: :all

    fill_in "Title", with: "NVIDIA RTX 4080 Super Founders Edition"
    fill_in "Description",
            with: "Graphics card in excellent condition with original box, cables and all accessories included."
    fill_in "Price", with: "899.50"
    select "Intel", from: "listing[specs][cpu_brand]"

    attach_file "listing[images][]", Rails.root.join("test/fixtures/files/gpu.jpg"), make_visible: true
    assert_selector "img[alt='gpu.jpg']"

    click_button "Accept all" if has_button?("Accept all")
    find("button[value='submit']").click

    assert_text I18n.t("listings.flash.submitted", locale: :en)
    assert_text "My listings"

    listing = Listing.find_by!(title: "NVIDIA RTX 4080 Super Founders Edition")
    assert listing.pending_review?
    assert listing.images.attached?
    assert_equal "intel", listing.specs["cpu_brand"]
  end
end
