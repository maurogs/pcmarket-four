require "test_helper"

class AdminAccessTest < ActionDispatch::IntegrationTest
  test "anonymous visitors are sent to sign in" do
    get admin_root_path(locale: :es)

    assert_redirected_to new_user_session_path(locale: :es)
  end

  test "signed-in regular users are redirected away from the admin panel" do
    sign_in users(:seller)

    get admin_root_path(locale: :es)

    assert_redirected_to root_path
  end

  test "moderators can open the admin panel" do
    sign_in users(:moderator)

    get admin_root_path(locale: :es)

    assert_response :success
    assert_select "h1", text: I18n.t("admin.dashboard.title")
    assert_select "aside a[href='#{admin_moderation_queue_path(locale: :es)}']"
  end

  test "moderators cannot perform admin-only actions" do
    sign_in users(:moderator)

    post admin_user_ban_path(users(:buyer), locale: :es), params: { reason: "test" }

    assert_redirected_to root_path
    assert_equal "active", users(:buyer).reload.status
  end

  test "moderators cannot bulk delete listings" do
    sign_in users(:moderator)
    listing = listings(:published_gpu)

    post admin_bulk_listing_actions_path(locale: :es),
         params: { listing_ids: [ listing.id ], bulk_action: "delete" }

    assert_redirected_to root_path
    assert Listing.exists?(listing.id)
  end
end
