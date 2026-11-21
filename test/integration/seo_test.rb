require "test_helper"

class SeoTest < ActionDispatch::IntegrationTest
  test "robots.txt disallows crawling outside production" do
    get "/robots.txt"

    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_includes response.body, "User-agent: *"
    assert_includes response.body, "Disallow: /"
  end

  test "sitemap.xml lists categories, listings, stores and legal pages" do
    get "/sitemap.xml"

    assert_response :success
    assert_includes [ "application/xml", "text/xml" ], response.media_type

    body = response.body
    assert_includes body, "/es/c/components"
    assert_includes body, "/es/l/#{listings(:published_gpu).slug}"
    assert_includes body, "/es/s/#{stores(:seller_store).slug}"
    assert_includes body, "/es/legal/terms"
    assert_includes body, "hreflang=\"en\""
    assert_includes body, "hreflang=\"x-default\""
  end

  test "sitemap.xml is served for every locale alternative" do
    get "/sitemap.xml"

    I18n.available_locales.each do |locale|
      assert_includes response.body, "/#{locale}/c/components"
    end
  end
end
