require "application_system_test_case"

class CheckoutFlowTest < ApplicationSystemTestCase
  test "guest adds an item and completes bank transfer checkout" do
    listing = listings(:published_gpu)
    visit "/en/l/#{listing.slug}"

    click_button I18n.t("listings.show.add_to_cart", locale: :en)
    click_button "Accept all" if has_button?("Accept all")

    visit "/en/cart"
    assert_selector "h1", text: I18n.t("cart.title", locale: :en)
    click_link I18n.t("cart.checkout_guest", locale: :en)

    assert_selector "h1", text: I18n.t("checkout.title", locale: :en)
    fill_in "checkout_email", with: "system-guest@example.com"

    find("summary", text: I18n.t("checkout.steps.delivery", locale: :en)).click
    fill_in "checkout_full_name", with: "System Guest"
    fill_in "checkout_line1", with: "Calle de Alcalá 1"
    fill_in "checkout_city", with: "Madrid"
    fill_in "checkout_postal_code", with: "28001"
    select "Comunidad de Madrid", from: "checkout_region_id"

    find("summary", text: I18n.t("checkout.steps.payment", locale: :en)).click
    choose "checkout_payment_method_bank_transfer"

    find("summary", text: I18n.t("checkout.steps.review", locale: :en)).click
    check "checkout_terms_accepted"
    check "checkout_withdrawal_acknowledged"
    click_button I18n.t("checkout.review.submit", locale: :en)

    assert_selector "h1", text: I18n.t("checkout.confirmation.title", locale: :en)
    assert_text I18n.t("orders.payment.bank_transfer.iban", locale: :en)
    order = Order.find_by!(buyer_email: "system-guest@example.com")
    assert_text order.number
    assert order.pending_payment?
    assert listing.reload.sold?
  end

  teardown do
    page.driver.browser.execute_cdp("Network.clearBrowserCookies")
  end
end
