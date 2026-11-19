require "test_helper"

class Account::DataExportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:confirmed)
    sign_in @user
    # Warden's test-mode sign_in only injects the user into the *next*
    # request; warm the session up with one successful request first.
    get "/en/account/data_export"
    assert_response :success
  end

  # --- Authentication -----------------------------------------------------------

  test "requires a signed-in user" do
    sign_out @user

    get "/en/account/data_export"
    assert_redirected_to "/en/users/sign_in"

    post "/en/account/data_export"
    assert_redirected_to "/en/users/sign_in"
  end

  # --- Show ---------------------------------------------------------------------

  test "show explains the export and offers the request button" do
    assert_select "form[action=?] button", "/en/account/data_export"
    assert_select "a", text: I18n.t("account.data_exports.show.download", locale: :en), count: 0
  end

  test "show links to the attachment once an export exists" do
    Accounts::DataExporter.call(@user)

    get "/en/account/data_export"

    assert_response :success
    assert_select "a[href^=?]", "/rails/active_storage/blobs/redirect/"
    assert_select "a", text: I18n.t("account.data_exports.show.download", locale: :en)
  end

  test "request button is disabled while throttled" do
    @user.update!(data_export_generated_at: 2.hours.ago)

    get "/en/account/data_export"

    assert_response :success
    assert_select "form[action=?] button[disabled]", "/en/account/data_export"
  end

  # --- Create -------------------------------------------------------------------

  test "create enqueues the export job" do
    assert_enqueued_with(job: Account::DataExportJob, args: [ @user.id ]) do
      post "/en/account/data_export"
    end

    assert_redirected_to "/en/account/data_export"
    assert_equal I18n.t("account.data_exports.create.requested", locale: :en), flash[:notice]
  end

  test "create runs the job and the export becomes downloadable" do
    perform_enqueued_jobs do
      post "/en/account/data_export"
    end

    assert_predicate @user.reload.data_export, :attached?
    assert_not_nil @user.data_export_generated_at

    get "/en/account/data_export"
    assert_response :success
    assert_select "a", text: I18n.t("account.data_exports.show.download", locale: :en)
  end

  test "create is throttled to once per 24 hours" do
    @user.update!(data_export_generated_at: 2.hours.ago)

    assert_no_enqueued_jobs do
      post "/en/account/data_export"
    end

    assert_redirected_to "/en/account/data_export"
    assert_equal I18n.t("account.data_exports.create.throttled", locale: :en), flash[:alert]
  end
end
