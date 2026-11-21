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
end
