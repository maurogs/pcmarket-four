require "test_helper"

class ExpireUnpaidOrdersJobTest < ActiveJob::TestCase
  setup do
    @listing = listings(:published_gpu)
    @order = Order.create!(
      buyer: users(:buyer), seller: users(:seller), store: stores(:seller_store),
      status: :pending_payment, fulfilment: :shipping, buyer_email: users(:buyer).email,
      payment_method: "bank_transfer", payment_provider: "bank_transfer",
      shipping_cents: 500
    )
    @order.order_items.create!(listing: @listing, title_snapshot: @listing.title,
                               price_cents: @listing.price_cents, quantity: 1)
    @order.compute_totals!
    @listing.update_columns(quantity: 0, status: Listing.statuses[:sold], updated_at: Time.current)
    @order.update_columns(created_at: 5.days.ago, updated_at: 5.days.ago)
  end

  test "cancels old unpaid bank transfer orders and restores stock" do
    ExpireUnpaidOrdersJob.perform_now

    assert @order.reload.cancelled?
    assert_equal "payment_expired", @order.cancel_reason
    assert @listing.reload.published?
    assert_equal 1, @listing.quantity
    assert_not_nil @order.stock_restored_at
  end

  test "does not cancel recent orders" do
    @order.update_columns(created_at: 1.hour.ago, updated_at: 1.hour.ago)

    ExpireUnpaidOrdersJob.perform_now

    assert @order.reload.pending_payment?
    assert_equal 0, @listing.reload.quantity
  end

  test "restores stock only once when run twice" do
    ExpireUnpaidOrdersJob.perform_now
    ExpireUnpaidOrdersJob.perform_now

    assert_equal 1, @listing.reload.quantity
    assert @order.reload.cancelled?
  end
end
