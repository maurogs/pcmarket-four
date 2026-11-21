require "application_system_test_case"

class ResponsiveTest < ApplicationSystemTestCase
  setup do
    @listing = listings(:published_gpu)
  end

  test "home, category, listing and store pages do not overflow at 390px" do
    [
      "/es",
      "/es/c/components/graphics-cards",
      "/es/l/#{@listing.slug}",
      "/es/s/#{stores(:seller_store).slug}"
    ].each do |path|
      visit path
      assert_selector "main", visible: true

      resize_to(390, 844)
      assert_no_horizontal_overflow(path)
    end
  end

  test "home, category, listing and store pages do not overflow at 768px" do
    [
      "/es",
      "/es/c/components/graphics-cards",
      "/es/l/#{@listing.slug}",
      "/es/s/#{stores(:seller_store).slug}"
    ].each do |path|
      visit path
      resize_to(768, 1024)
      assert_no_horizontal_overflow(path)
    end
  end

  test "desktop navigation does not overflow at 1440px" do
    visit "/es"
    resize_to(1440, 900)

    assert_no_horizontal_overflow("/es")
    assert_selector "nav a", text: I18n.t("layout.nav.new")
  end

  private

  def resize_to(width, height)
    page.driver.browser.execute_cdp(
      "Emulation.setDeviceMetricsOverride",
      width: width, height: height, deviceScaleFactor: 1, mobile: width < 768
    )
    sleep 0.2
  end

  def assert_no_horizontal_overflow(path)
    scroll_width = page.evaluate_script("document.documentElement.scrollWidth")
    client_width = page.evaluate_script("document.documentElement.clientWidth")

    assert_operator scroll_width, :<=, client_width,
                    "Expected #{path} not to overflow horizontally " \
                    "(scrollWidth=#{scroll_width}, clientWidth=#{client_width})"
  end
end
