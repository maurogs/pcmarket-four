require "test_helper"

class AdminReportsTest < ActionDispatch::IntegrationTest
  setup do
    @report = reports(:buyer_reports_gpu)
    sign_in users(:admin)
  end

  test "index renders filters and status counts" do
    get admin_reports_path(locale: :es)

    assert_response :success
    assert_select "#admin-filter-status"
    assert_select "#admin-filter-reportable_type"
    assert_match I18n.t("admin.reports.statuses.open"), response.body
  end

  test "show renders the reported listing and other reports" do
    get admin_report_path(@report, locale: :es)

    assert_response :success
    assert_match listings(:published_gpu).title, response.body
    assert_select "form[action='#{admin_report_path(@report, locale: :es)}']", minimum: 1
  end

  test "resolving with hide_listing pauses the listing and notifies the reporter" do
    assert_difference -> { Notification.count }, 1 do
      patch admin_report_path(@report, locale: :es),
            params: { report: { decision: "resolve", action: "hide_listing" } }
    end

    assert_redirected_to admin_reports_path
    assert_equal "resolved", @report.reload.status
    assert_equal "paused", listings(:published_gpu).reload.status
    assert AdminAuditLog.exists?(auditable: @report, action: "report.resolved")
  end

  test "resolving with suspend_user suspends the reported user" do
    report = Report.create!(reporter: users(:buyer), reportable: users(:seller),
                            reason: :fraud, details: "No envía los pedidos.")

    patch admin_report_path(report, locale: :es),
          params: { report: { decision: "resolve", action: "suspend_user" } }

    assert_equal "suspended", users(:seller).reload.status
  end

  test "resolving with delete_review unpublishes it and is admin only" do
    report = Report.create!(reporter: users(:buyer), reportable: reviews(:delivered_order_review),
                            reason: :offensive, details: "Lenguaje inapropiado.")

    patch admin_report_path(report, locale: :es),
          params: { report: { decision: "resolve", action: "delete_review" } }
    assert_equal false, reviews(:delivered_order_review).reload.published

    sign_out users(:admin)
    sign_in users(:moderator)
    other = Report.create!(reporter: users(:buyer), reportable: reviews(:delivered_order_review),
                           reason: :spam, details: "Duplicada.")

    patch admin_report_path(other, locale: :es),
          params: { report: { decision: "resolve", action: "delete_review" } }
    assert_redirected_to root_path
  end

  test "dismissing a report leaves the target untouched and notifies the reporter" do
    assert_difference -> { Notification.count }, 1 do
      patch admin_report_path(@report, locale: :es),
            params: { report: { decision: "dismiss" } }
    end

    assert_equal "dismissed", @report.reload.status
    assert_equal "published", listings(:published_gpu).reload.status
  end

  test "bulk dismiss closes every selected report" do
    second = Report.create!(reporter: users(:seller), reportable: listings(:published_gpu),
                            reason: :other, details: "Segunda denuncia.")

    post admin_bulk_report_actions_path(locale: :es),
         params: { report_ids: [ @report.id, second.id ] }

    assert_redirected_to admin_reports_path
    assert_equal "dismissed", @report.reload.status
    assert_equal "dismissed", second.reload.status
  end
end
