require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  PagesController::PAGES.each do |page|
    test "allows the #{page} page" do
      get "/pages/#{page}"
      assert_response :success
    end
  end

  test "rejects unknown pages" do
    get "/pages/some-secret-page"
    assert_response :not_found
  end
end
