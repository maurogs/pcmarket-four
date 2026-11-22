require "test_helper"

module Api
  module V1
    class MessagingTest < ActionDispatch::IntegrationTest
      include ApiTestHelper

      setup do
        @buyer = users(:buyer)
        @seller = users(:seller)
        @conversation = conversations(:buyer_seller_gpu)
        @seller_token = issue_token_for(@seller)
      end

      test "lists conversations with unread counts" do
        api_get "/api/v1/conversations"

        assert_response :ok
        conversation = json_body["data"].find { |item| item["id"] == @conversation.id }
        assert conversation
        assert conversation.key?("unread_count")
        assert json_body["meta"].key?("unread_total")
      end

      test "shows a conversation newest first and marks it read" do
        api_get "/api/v1/conversations/#{@conversation.id}"

        assert_response :ok
        assert json_body["data"]["messages"].any?
        assert json_body["meta"]["newest_first"]
        assert_equal 0, @conversation.reload.buyer_unread_count
      end

      test "starts a conversation through ConversationStarter" do
        post "/api/v1/conversations",
             params: { listing_id: listings(:published_gpu).id, body: "¿Sigue disponible?" },
             headers: api_headers, as: :json

        assert_response :created
        assert_equal @conversation.id, json_body.dig("data", "id")
      end

      test "sends a message and marks the conversation read" do
        post "/api/v1/conversations/#{@conversation.id}/messages",
             params: { body: "Sí, sigue disponible." }, headers: api_headers(@seller_token), as: :json

        assert_response :created
        assert_equal "Sí, sigue disponible.", json_body.dig("data", "body")

        post "/api/v1/conversations/#{@conversation.id}/read",
             headers: api_headers(@seller_token), as: :json
        assert_response :ok
      end

      test "sends an offer and the seller accepts it" do
        post "/api/v1/conversations/#{@conversation.id}/offers",
             params: { amount: "480,00" }, headers: api_headers, as: :json

        assert_response :created
        message_id = json_body.dig("data", "id")
        assert_equal "offer", json_body.dig("data", "kind")
        assert_equal 48_000, json_body.dig("data", "offer_amount_cents")

        post "/api/v1/messages/#{message_id}/offer_response",
             params: { decision: "accept" }, headers: api_headers(@seller_token), as: :json

        assert_response :ok
        assert_equal "accepted", json_body.dig("data", "offer_status")
      end

      test "blocks and unblocks a user" do
        post "/api/v1/blocks", params: { user_id: @seller.id }, headers: api_headers, as: :json
        assert_response :created
        block_id = json_body.dig("data", "id")
        assert Block.exists?(blocker: @buyer, blocked: @seller)

        delete "/api/v1/blocks/#{block_id}", headers: api_headers
        assert_response :no_content
        assert_not Block.exists?(block_id)
      end

      test "reads notifications and marks all read" do
        api_get "/api/v1/notifications"
        assert_response :ok
        notification = json_body["data"].first
        assert notification

        patch "/api/v1/notifications/#{notification['id']}", headers: api_headers, as: :json
        assert_response :ok
        assert json_body.dig("data", "read")

        post "/api/v1/notifications/read_all", headers: api_headers, as: :json
        assert_response :created
        assert_equal 0, @buyer.notifications.unread.count
      end

      test "registers and removes a push device token" do
        post "/api/v1/me/devices",
             params: { platform: "ios", token: "device-token-abc", app_version: "1.2.0" },
             headers: api_headers, as: :json

        assert_response :created
        device_id = json_body.dig("data", "id")
        assert_equal "ios", json_body.dig("data", "platform")

        delete "/api/v1/me/devices/#{device_id}", headers: api_headers
        assert_response :no_content
        assert_not Device.exists?(device_id)
      end

      test "rejects unknown device platforms" do
        post "/api/v1/me/devices",
             params: { platform: "windows", token: "nope" }, headers: api_headers, as: :json

        assert_response :unprocessable_entity
      end

      test "reports a listing" do
        post "/api/v1/reports",
             params: { reportable_type: "Listing",
                       reportable_id: listings(:draft_gpu).id, reason: "spam" },
             headers: api_headers, as: :json

        assert_response :created
        assert Report.exists?(reporter: @buyer, reportable: listings(:draft_gpu))
      end

      test "updates the profile and notification preferences" do
        patch "/api/v1/me",
              params: { first_name: "Bruno Updated", locale: "en",
                        notification_preferences: { email_messages: false } },
              headers: api_headers, as: :json

        assert_response :ok
        assert_equal "Bruno Updated", json_body.dig("data", "first_name")
        assert_equal "en", json_body.dig("data", "locale")
        assert_equal false, @buyer.reload.notification_preferences["email_messages"]
      end

      test "exports and deletes the current account" do
        api_get "/api/v1/me/export"
        assert_response :ok
        assert json_body.dig("data", "user", "email").present?

        delete "/api/v1/me", headers: api_headers
        assert_response :no_content
        assert @buyer.reload.deleted_at.present?
      end
    end
  end
end
