require "test_helper"

module Api
  module V1
    class CheckoutTest < ActionDispatch::IntegrationTest
      include ApiTestHelper
      include OrderTestHelper

      setup do
        @buyer = users(:buyer)
        @seller = users(:seller)
        @listing = listings(:published_gpu)
        @seller_token = issue_token_for(@seller)
      end

      test "returns the cart read model" do
        api_get "/api/v1/cart"

        assert_response :ok
        data = json_body["data"]
        assert data["item_count"].positive?
        assert data["groups"].any?
        assert_equal @listing.price_cents, data.dig("groups", 0, "items", 0, "listing", "price", "cents")
      end

      test "adds, updates and removes cart items" do
        target = @listing

        post "/api/v1/cart_items",
             params: { listing_id: target.id, quantity: 1 }, headers: api_headers, as: :json
        assert_includes [ 200, 201 ], response.status

        item = CartItem.find_by(user: @buyer, listing: target)

        patch "/api/v1/cart_items/#{item.id}", params: { quantity: 2 },
                                               headers: api_headers, as: :json
        assert_response :ok

        delete "/api/v1/cart_items/#{item.id}", headers: api_headers
        assert_response :ok
        assert_not CartItem.exists?(item.id)
      end

      test "returns checkout options" do
        api_get "/api/v1/checkout/options"

        assert_response :ok
        data = json_body["data"]
        assert_includes data["payment_methods"].map { |method| method["key"] }, "bank_transfer"
        assert data["groups"].any?
        assert data["groups"].first["delivery_options"].any?
        assert json_body.dig("meta", "checkout_token").present?
      end

      test "places a bank transfer order end to end" do
        api_get "/api/v1/checkout/options"
        token = json_body.dig("meta", "checkout_token")

        post "/api/v1/checkout",
             params: {
               email: @buyer.email,
               payment_method: "bank_transfer",
               delivery: { @seller.id.to_s => "shipping" },
               address_id: addresses(:buyer_address).id,
               save_address: false,
               terms_accepted: true,
               withdrawal_acknowledged: true,
               checkout_token: token
             },
             headers: api_headers, as: :json

        assert_response :created
        data = json_body["data"]
        assert_equal "bank_transfer", data["payment_method"]
        assert data["orders"].any?
        assert_equal Setting.get("bank_iban"), data.dig("payment_instructions", "iban")
        assert_nil data["redirect_url"]

        order = Order.find_by!(number: data["orders"].first["number"])
        assert_equal @buyer.id, order.buyer_id
        assert_equal 0, CartItem.where(user: @buyer).count
      end

      test "rejects checkout without legal acceptance" do
        post "/api/v1/checkout",
             params: {
               email: @buyer.email,
               payment_method: "bank_transfer",
               delivery: { @seller.id.to_s => "shipping" },
               address_id: addresses(:buyer_address).id
             },
             headers: api_headers, as: :json

        assert_error_envelope 422, "validation_failed"
      end

      test "lists and shows buyer orders" do
        order = create_order(status: :delivered)

        api_get "/api/v1/me/orders?status=in_progress"
        assert_response :ok
        assert json_body["data"].any?

        api_get "/api/v1/me/orders/#{order.number}"
        assert_response :ok
        assert_equal order.number, json_body.dig("data", "number")
      end

      test "cancels an unpaid order" do
        order = create_order(status: :pending_payment)

        post "/api/v1/me/orders/#{order.number}/cancellation",
             params: { reason: "changed_mind" }, headers: api_headers, as: :json

        assert_response :ok
        assert_equal "cancelled", order.reload.status
      end

      test "confirms delivery" do
        order = create_order(status: :shipped)

        post "/api/v1/me/orders/#{order.number}/delivery_confirmation",
             headers: api_headers, as: :json

        assert_response :ok
        assert_equal "delivered", order.reload.status
      end

      test "opens a dispute inside the inspection window" do
        order = create_order(status: :shipped)

        post "/api/v1/me/orders/#{order.number}/dispute",
             params: { reason: "damaged", details: "La caja llegó golpeada." },
             headers: api_headers, as: :json

        assert_response :ok
        assert_equal "disputed", order.reload.status
      end

      test "reviews a completed order" do
        order = create_order(status: :completed)

        post "/api/v1/me/orders/#{order.number}/review",
             params: { rating: 5, body: "Vendedor muy rápido y producto impecable, repetiré." },
             headers: api_headers, as: :json

        assert_response :created
        assert_equal 5, order.reload.review.rating
      end

      test "forbids acting on another buyer order" do
        other = create_order(status: :pending_payment, buyer: users(:admin))

        post "/api/v1/me/orders/#{other.number}/cancellation", headers: api_headers, as: :json

        assert_response :not_found
        assert other.reload.pending_payment?
      end

      test "lists seller sales and ships an order" do
        order = create_order(status: :paid, payment_method: "bank_transfer")

        api_get "/api/v1/me/sales?status=to_ship", token: @seller_token
        assert_response :ok
        assert json_body["data"].any?

        post "/api/v1/me/sales/#{order.number}/shipment",
             params: { carrier: "correos", tracking_number: "ABC123456" },
             headers: api_headers(@seller_token), as: :json

        assert_response :ok
        assert_equal "shipped", order.reload.status
        assert_equal "ABC123456", order.tracking_number
      end

      test "marks a pickup ready and cancels as seller" do
        pickup = create_order(status: :paid, fulfilment: :local_pickup, payment_method: "cash_on_pickup")

        post "/api/v1/me/sales/#{pickup.number}/pickup", headers: api_headers(@seller_token), as: :json
        assert_response :ok

        order = create_order(status: :paid, payment_method: "bank_transfer")
        post "/api/v1/me/sales/#{order.number}/cancellation",
             params: { reason: "out_of_stock", refund_required: true },
             headers: api_headers(@seller_token), as: :json

        assert_response :ok
        assert_equal "cancelled", order.reload.status
        assert order.refund_required?
      end
    end
  end
end
