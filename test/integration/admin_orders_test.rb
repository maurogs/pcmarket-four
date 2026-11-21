require "test_helper"

class AdminOrdersTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:admin) }

  test "index renders filters, totals and rows" do
    get admin_orders_path(locale: :es)

    assert_response :success
    assert_select "#admin-filter-status"
    assert_select "#admin-filter-payment_method"
    assert_match I18n.t("admin.orders.totals.gmv"), response.body
    assert_match orders(:delivered_order).number, response.body
  end

  test "show renders order detail, timeline, notes and audit history" do
    order = orders(:delivered_order)
    order.order_notes.create!(author: users(:admin), body: "Cliente VIP")

    get admin_order_path(order, locale: :es)

    assert_response :success
    assert_select "h1", text: I18n.t("admin.orders.show.title", number: order.number)
    assert_match "Cliente VIP", response.body
    assert_match I18n.t("admin.orders.show.timeline"), response.body
    assert_match I18n.t("admin.orders.show.history"), response.body
  end

  test "marking a bank transfer as paid requires a reference and notifies" do
    order = create_order(status: :pending_payment, payment_method: "bank_transfer")

    post admin_order_payment_path(order, locale: :es), params: { payment_reference: "" }
    assert_equal "pending_payment", order.reload.status
    assert_equal I18n.t("admin.orders.reference_required"), flash[:alert]

    assert_difference -> { Notification.count }, 2 do
      post admin_order_payment_path(order, locale: :es), params: { payment_reference: "TRX-42" }
    end

    assert_redirected_to admin_order_path(order)
    assert_equal "paid", order.reload.status
    assert_equal "TRX-42", order.payment_reference
    assert AdminAuditLog.exists?(auditable: order, action: "order.paid")
  end

  test "refund records the reference and is admin only" do
    order = create_order(status: :paid)
    post admin_order_refund_path(order, locale: :es), params: { refund_reference: "RF-9" }

    assert_equal "refunded", order.reload.status
    assert_equal "RF-9", order.refund_reference
    assert AdminAuditLog.exists?(auditable: order, action: "order.refunded")

    sign_out users(:admin)
    sign_in users(:moderator)
    other = create_order(status: :paid)

    post admin_order_refund_path(other, locale: :es), params: { refund_reference: "RF-10" }

    assert_equal "paid", other.reload.status
    assert_redirected_to root_path
  end

  test "internal notes are stored and audited" do
    order = orders(:delivered_order)

    assert_difference -> { OrderNote.count }, 1 do
      post admin_order_notes_path(order, locale: :es), params: { body: "Llamar al comprador" }
    end

    assert_equal "Llamar al comprador", order.order_notes.last.body
    assert AdminAuditLog.exists?(auditable: order, action: "order.note_added")
  end

  test "CSV export uses the current filters" do
    post admin_order_exports_path(locale: :es), params: { status: "delivered" }

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_match orders(:delivered_order).number, response.body
    assert_no_match orders(:pending_order).number, response.body
  end

  test "bulk payments summarises paid, missing and wrong-status orders" do
    first = create_order(status: :pending_payment, payment_method: "bank_transfer")
    second = create_order(status: :pending_payment, payment_method: "bank_transfer")
    paid = create_order(status: :paid)

    post admin_bulk_payments_path(locale: :es), params: {
      order_numbers: [ first.number, second.number, paid.number, "PCM-2026-999999" ].join("\n"),
      payment_reference: "BULK-1"
    }

    assert_response :success
    assert_equal "paid", first.reload.status
    assert_equal "paid", second.reload.status
    assert_equal "paid", paid.reload.status
    assert_match I18n.t("admin.payments.bulk.result_title"), response.body
    assert_match "PCM-2026-999999", response.body
  end

  test "payments reconciliation lists pending bank transfers with deadline" do
    order = create_order(status: :pending_payment, payment_method: "bank_transfer")

    get admin_payments_path(locale: :es)

    assert_response :success
    assert_match order.number, response.body
    assert_match I18n.t("admin.payments.bulk.title"), response.body
  end
end
