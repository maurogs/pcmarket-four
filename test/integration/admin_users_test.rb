require "test_helper"

class AdminUsersTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:admin) }

  test "suspending a user blocks sign-in and hides their listings" do
    seller = users(:seller)

    post admin_user_suspension_path(seller, locale: :es), params: { reason: "Spam behaviour" }
    assert_redirected_to admin_user_path(seller, locale: :es)
    assert_equal "suspended", seller.reload.status
    assert_equal "Spam behaviour", seller.suspension_reason
    assert_not_includes Listing.visible, listings(:published_gpu)

    sign_out :user
    post user_session_path(locale: :es),
         params: { user: { email: seller.email, password: "Password123!" } }

    assert_response :redirect
    follow_redirect!
    assert_match I18n.t("devise.failure.suspended", locale: :es), response.body
  end

  test "unsuspending restores access" do
    seller = users(:seller)
    seller.update!(status: :suspended)

    delete admin_user_suspension_path(seller, locale: :es)

    assert_equal "active", seller.reload.status
    assert_includes Listing.visible, listings(:published_gpu)
  end

  test "banning archives listings and is admin-only" do
    seller = users(:seller)

    post admin_user_ban_path(seller, locale: :es), params: { reason: "Fraud" }

    assert_equal "banned", seller.reload.status
    assert_equal "archived", listings(:published_gpu).reload.status
    assert AdminAuditLog.where(action: "user.banned").exists?

    sign_out :user
    sign_in users(:moderator)
    post admin_user_ban_path(users(:buyer), locale: :es), params: { reason: "Nope" }

    assert_redirected_to root_path
    assert_equal "active", users(:buyer).reload.status
  end

  test "an admin cannot change their own role" do
    patch admin_user_role_path(users(:admin), locale: :es), params: { role: "moderator" }

    assert_redirected_to admin_user_path(users(:admin), locale: :es)
    assert_equal "admin", users(:admin).reload.role
    assert_match I18n.t("admin.users.cannot_change_own_role", locale: :es), flash[:alert]
  end

  test "the last admin cannot be demoted at the service level" do
    error = assert_raises Admin::UserModeration::Error do
      Admin::UserModeration.change_role(users(:admin), "moderator", actor: users(:moderator))
    end

    assert_equal "last_admin", error.message
    assert_equal "admin", users(:admin).reload.role
  end

  test "an admin can promote a moderator" do
    patch admin_user_role_path(users(:moderator), locale: :es), params: { role: "admin" }

    assert_equal "admin", users(:moderator).reload.role
    assert AdminAuditLog.where(action: "user.role_changed").exists?
  end

  test "impersonation starts and stops with a banner" do
    seller = users(:seller)

    post admin_user_impersonation_path(seller, locale: :es)

    assert_redirected_to root_path(locale: :es)
    follow_redirect!
    assert_match I18n.t("admin.impersonation.banner", name: seller.display_name, locale: :es), response.body

    delete admin_impersonation_path(locale: :es)

    assert_redirected_to admin_root_path(locale: :es)
    follow_redirect!
    assert_match I18n.t("admin.dashboard.title", locale: :es), response.body
    assert AdminAuditLog.where(action: "user.impersonated").exists?
    assert AdminAuditLog.where(action: "user.impersonation_stopped").exists?
  end

  test "an admin cannot impersonate another admin" do
    other_admin = users(:moderator)
    other_admin.update!(role: :admin)

    post admin_user_impersonation_path(other_admin, locale: :es)

    assert_redirected_to root_path
    get admin_root_path(locale: :es)
    assert_response :success
    assert_not AdminAuditLog.where(action: "user.impersonated").exists?
  end

  test "CSV export contains filtered users" do
    post admin_user_exports_path(locale: :es), params: { role: "moderator" }

    assert_response :success
    assert_match "text/csv", response.content_type
    assert_equal 2, response.body.lines.size
    assert_includes response.body, users(:moderator).email
    assert_includes response.body, "moderator"
    assert_not_includes response.body, users(:seller).email
  end

  test "manual confirmation and password reset are audited" do
    user = users(:buyer)
    user.update_columns(confirmed_at: nil)

    post admin_user_confirmation_path(user, locale: :es)
    assert user.reload.confirmed_at.present?

    assert_emails 1 do
      post admin_user_password_reset_path(user, locale: :es)
    end

    assert AdminAuditLog.where(action: "user.confirmed").exists?
    assert AdminAuditLog.where(action: "user.password_reset_sent").exists?
  end

  test "soft delete anonymises the account" do
    user = users(:buyer)

    post admin_user_deletion_path(user, locale: :es)

    assert_redirected_to admin_users_path(locale: :es)
    user.reload
    assert user.deleted?
    assert_match(/\Adeleted-user-/, user.username)
    assert_match(/@example\.invalid\z/, user.email)
  end
end
