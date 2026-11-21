require "test_helper"

class AdminAccessTest < ActionDispatch::IntegrationTest
  test "non-staff visitors are redirected away from the admin panel" do
    get admin_root_path(locale: :es)

    assert_redirected_to root_path
    follow_redirect!
    assert_match I18n.t("errors.not_authorized"), response.body
  end

  test "signed-in regular users are redirected away from the admin panel" do
    sign_in users(:seller)

    get admin_root_path(locale: :es)

    assert_redirected_to root_path
  end

  test "staff can open the admin panel" do
    sign_in users(:admin)

    get admin_root_path(locale: :es)

    assert_response :success
    assert_select "h1", text: I18n.t("pages.admin.title")
  end
end
