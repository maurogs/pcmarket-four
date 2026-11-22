require "application_system_test_case"

class ResponsiveTest < ApplicationSystemTestCase
  setup do
    @gaming_category = Category.find_or_create_by!(slug: "gaming-pcs") do |category|
      category.names = {
        "es" => "PC Gaming", "en" => "Gaming PCs", "fr" => "PC Gaming",
        "de" => "Gaming-PCs", "it" => "PC Gaming", "pt" => "PC Gaming"
      }
      category.position = 99
      category.active = true
    end
    @listing = create_demo_like_listings.first
  end

  test "public and authenticated screens do not overflow at 390px" do
    assert_screens_do_not_overflow(390, 844)
  end

  test "public and authenticated screens do not overflow at 768px" do
    assert_screens_do_not_overflow(768, 1024)
  end

  test "desktop navigation does not overflow at 1440px" do
    visit "/es"
    resize_to(1440, 900)

    assert_no_horizontal_overflow("/es")
    assert_selector "nav a", text: I18n.t("layout.nav.new")
  end

  private

  def assert_screens_do_not_overflow(width, height)
    resize_to(width, height)

    [
      "/es",
      "/es/c/gaming-pcs",
      "/es/search?q=rtx",
      "/es/l/#{@listing.slug}",
      "/es/s/#{stores(:seller_store).slug}"
    ].each { |path| visit_and_check(path) }

    sign_in_as(users(:buyer))
    [ "/es/cart", "/es/checkout", "/es/conversations" ].each { |path| visit_and_check(path) }

    sign_in_as(users(:seller))
    visit_and_check("/es/seller")

    sign_in_as(users(:admin))
    visit_and_check("/es/admin")
  end

  def visit_and_check(path)
    visit path
    assert_selector "main", visible: true
    assert_no_horizontal_overflow(path)
  end

  def sign_in_as(user)
    clear_browser_state
    page.driver.browser.navigate.to("about:blank")
    visit "/es/users/sign_in"
    page.refresh
    accept_cookies
    fill_in "user_email", with: user.email
    fill_in "user_password", with: "Password123!"
    page.find("form[action*='users/sign_in']").native.submit
    assert_selector "header [aria-label='#{I18n.t("layout.header.account", locale: :es)}']"
  end

  def accept_cookies
    label = I18n.t("layout.cookies.accept_all", locale: :es)
    click_button label if page.has_button?(label, wait: 0)
  end

  def create_demo_like_listings
    specs = [
      { "gpu_model" => "NVIDIA GeForce RTX 4070 Super", "cpu" => "AMD Ryzen 7 7800X3D",
        "cpu_brand" => "amd", "memory_capacity" => "32 GB", "storage_capacity" => "2 TB NVMe" },
      { "gpu_model" => "AMD Radeon RX 7900 XTX", "cpu" => "Intel Core i9-14900K",
        "cpu_brand" => "intel", "memory_capacity" => "64 GB", "storage_capacity" => "4 TB NVMe" },
      { "gpu_model" => "NVIDIA GeForce RTX 4090", "cpu" => "AMD Ryzen 9 9950X",
        "cpu_brand" => "amd", "memory_capacity" => "128 GB", "storage_capacity" => "8 TB NVMe" }
    ]

    [
      "PC Gaming definitivo con RTX 4070 Super, Ryzen 7 y refrigeración líquida personalizada",
      "Torre gaming blanca con cristal templado, iluminación RGB y componentes de gama alta",
      "Ordenador para streaming y edición 4K con capturadora, dos monitores y soporte articulado"
    ].each_with_index.map do |title, index|
      listing = Listing.create!(
        user: users(:seller),
        store: stores(:seller_store),
        category: @gaming_category,
        title: title,
        description: "Equipo revisado y probado con todos sus componentes en perfecto estado de funcionamiento.",
        price_cents: 149_900 + (index * 100_000),
        original_price_cents: 199_900 + (index * 100_000),
        condition: :used_like_new,
        status: :published,
        published_at: index.days.ago,
        quantity: 1,
        specs: specs[index],
        labels: [ "pro_gamer", "deal" ],
        country_code: "ES",
        region: regions(:madrid),
        city: "Madrid",
        shipping_available: true,
        local_pickup: true,
        shipping_price_cents: 0,
        free_shipping: true
      )
      attach_image(listing)
      listing
    end
  end

  def attach_image(listing)
    path = Rails.root.join("test/fixtures/files/gpu.jpg")
    return unless path.exist?

    listing.images.attach(io: File.open(path), filename: "gpu.jpg", content_type: "image/jpeg")
  end

  def resize_to(width, height)
    page.driver.browser.execute_cdp(
      "Emulation.setDeviceMetricsOverride",
      width: width, height: height, deviceScaleFactor: 1, mobile: width < 768
    )
    sleep 0.2
  end

  def assert_no_horizontal_overflow(path)
    result = page.evaluate_script(<<~JS)
      (() => {
        const width = window.innerWidth;
        const clippedByAncestor = (element) => {
          for (let parent = element.parentElement;
               parent && parent !== document.body && parent !== document.documentElement;
               parent = parent.parentElement) {
            const overflow = getComputedStyle(parent).overflowX;
            if (["auto", "scroll", "hidden", "clip"].includes(overflow)) return true;
          }
          return false;
        };
        const selectorFor = (element) => {
          const tag = element.tagName.toLowerCase();
          if (element.id) return `${tag}#${element.id}`;
          const classes = Array.from(element.classList).slice(0, 3).join(".");
          return classes ? `${tag}.${classes}` : tag;
        };
        const offenders = Array.from(document.querySelectorAll("body *"))
          .filter((element) => {
            const rect = element.getBoundingClientRect();
            return rect.width > 0 && rect.height > 0 &&
              rect.right > width + 1 && !clippedByAncestor(element);
          })
          .slice(0, 8)
          .map((element) => {
            const rect = element.getBoundingClientRect();
            return `${selectorFor(element)} (right=${Math.round(rect.right)}, width=${Math.round(rect.width)})`;
          });

        return {
          scrollWidth: document.documentElement.scrollWidth,
          innerWidth: width,
          offenders
        };
      })()
    JS

    assert_operator result["scrollWidth"], :<=, result["innerWidth"],
                    "Expected #{path} not to overflow horizontally " \
                    "(scrollWidth=#{result['scrollWidth']}, innerWidth=#{result['innerWidth']}). " \
                    "Offending elements: #{result['offenders'].presence&.join(', ') || 'none'}"
    assert_empty result["offenders"],
                 "Expected #{path} not to push elements beyond the viewport. " \
                 "Offending elements: #{result['offenders'].join(', ')}"
  end
end
