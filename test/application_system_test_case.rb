require "test_helper"

# Chrome 158 rejects the wildcard origin used by Capybara when clearing
# storage between system tests. The driver has already navigated to
# about:blank and cleared cookies at that point, so the failure is safe to
# ignore.
module CapybaraWildcardStorageReset
  def reset!
    super
  rescue Selenium::WebDriver::Error::InvalidArgumentError => error
    raise unless error.message.include?("is not a valid URL")

    true
  end
end
Capybara::Selenium::Driver::ChromeDriver.prepend(CapybaraWildcardStorageReset)

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1440, 900 ]

  setup do
    reset_viewport
  end

  teardown do
    clear_browser_state
  end

  private

  def clear_browser_state
    page.driver.browser.manage.delete_all_cookies
    page.execute_script("window.localStorage.clear()") if page.current_url.present?
  rescue StandardError
    nil
  end

  # CDP overrides leak across tests when a responsive test resizes the page.
  def reset_viewport
    page.driver.browser.execute_cdp(
      "Emulation.setDeviceMetricsOverride",
      width: 1440, height: 900, deviceScaleFactor: 1, mobile: false
    )
  rescue Selenium::WebDriver::Error::WebDriverError
    nil
  end
end
