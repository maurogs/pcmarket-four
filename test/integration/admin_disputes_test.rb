require "test_helper"

class AdminDisputesTest < ActionDispatch::IntegrationTest
  setup do
    @order = create_order(status: :disputed)
    @order.order_events.create!(kind: "dispute_opened", actor: users(:buyer),
                                data: { reason: "damaged", details: "La tarjeta llegó rota." })
    sign_in users(:admin)
  end

  test "index lists disputed orders with their reason" do
    get admin_disputes_path(locale: :es)

    assert_response :success
    assert_match @order.number, response.body
    assert_match I18n.t("orders.dispute.reasons.damaged"), response.body
  end

  test "show renders dispute details, conversation and resolution form" do
    get admin_dispute_path(@order, locale: :es)

    assert_response :success
    assert_match "La tarjeta llegó rota.", response.body
    assert_match I18n.t("admin.disputes.show.resolve"), response.body
    assert_select "select#dispute_outcome"
  end

  test "refund resolution notifies both parties, sends emails and audits" do
    assert_difference -> { Notification.count }, 2 do
      assert_enqueued_jobs 2, only: ActionMailer::MailDeliveryJob do
        post admin_dispute_resolution_path(@order, locale: :es),
             params: { outcome: "refund", message: "Hemos reembolsado el importe completo." }
      end
    end

    assert_redirected_to admin_disputes_path
    assert_equal "refunded", @order.reload.status
    assert AdminAuditLog.exists?(auditable: @order, action: "order.dispute_resolved")
  end

  test "release resolution completes the order" do
    post admin_dispute_resolution_path(@order, locale: :es),
         params: { outcome: "release", message: "El artículo cumple lo descrito." }

    assert_equal "completed", @order.reload.status
    assert @order.order_events.where(kind: "dispute_resolved").exists?
  end

  test "moderators cannot refund a dispute" do
    sign_out users(:admin)
    sign_in users(:moderator)

    post admin_dispute_resolution_path(@order, locale: :es),
         params: { outcome: "refund", message: "No permitido." }

    assert_equal "disputed", @order.reload.status
    assert_redirected_to root_path
  end
end
