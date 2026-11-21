require "test_helper"

class AdminSidebarCountsTest < ActiveSupport::TestCase
  test "counts open disputes, open reports and pending payments" do
    create_order(status: :disputed)
    create_order(status: :pending_payment, payment_method: "bank_transfer")
    counts = Admin::SidebarCounts.call

    assert_operator counts[:open_disputes], :>=, 1
    assert_operator counts[:open_reports], :>=, 1
    assert_operator counts[:pending_payments], :>=, 1
  end

  test "caches the payload for one minute" do
    Admin::SidebarCounts.call
    create_order(status: :disputed)
    cached = Admin::SidebarCounts.call

    assert_equal 0, cached[:open_disputes]
  end
end
