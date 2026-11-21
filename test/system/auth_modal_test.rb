require "application_system_test_case"

class AuthModalTest < ApplicationSystemTestCase
  test "header login opens the sign in form inside a dialog" do
    resize_viewport(1280, 900)
    visit "/es"

    find("header a[aria-label='#{I18n.t("layout.header.login")}']", match: :first).click

    assert_selector "dialog#auth-dialog[open]", visible: true
    within("dialog#auth-dialog") do
      assert_selector "h1", text: I18n.t("auth.sign_in.title")
      assert_selector "input#user_email"
    end
  end

  test "authentication pages still work without the modal" do
    visit "/es/users/sign_in"

    assert_selector "h1", text: I18n.t("auth.sign_in.title")
    assert_selector "input#user_email"
  end

  private

  def resize_viewport(width, height)
    page.driver.browser.execute_cdp(
      "Emulation.setDeviceMetricsOverride",
      width: width, height: height, deviceScaleFactor: 1, mobile: false
    )
  end
end
