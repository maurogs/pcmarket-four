require "test_helper"

class MessagingTest < ActionDispatch::IntegrationTest
  setup do
    @buyer = users(:buyer)
    @seller = users(:seller)
    @listing = listings(:published_gpu)
    @conversation = conversations(:buyer_seller_gpu)
  end

  test "starting a chat reuses the same listing conversation" do
    sign_in @buyer

    assert_no_difference -> { Conversation.count } do
      post conversations_path(locale: :es), params: { listing_id: @listing.id }
    end

    assert_redirected_to conversation_path(@conversation, locale: :es)
  end

  test "starting your own listing conversation is rejected" do
    sign_in @seller

    assert_no_difference -> { Conversation.count } do
      post conversations_path(locale: :es), params: { listing_id: @listing.id }
    end

    assert_redirected_to listing_path(@listing, locale: :es)
    assert_equal I18n.t("messaging.errors.own_listing", locale: :es), flash[:alert]
  end

  test "blocked users cannot start a conversation" do
    Block.create!(blocker: @seller, blocked: @buyer)
    sign_in @buyer

    post conversations_path(locale: :es), params: { listing_id: @listing.id }

    assert_equal I18n.t("messaging.errors.blocked", locale: :es), flash[:alert]
  end

  test "chat disabled prevents new conversations and shows a notice" do
    Setting.set("chat_enabled", false)
    sign_in @buyer

    post conversations_path(locale: :es), params: { listing_id: @listing.id }
    assert_equal I18n.t("messaging.errors.chat_disabled", locale: :es), flash[:alert]

    get conversations_path(locale: :es)
    assert_response :success
    assert_match I18n.t("messaging.inbox.chat_disabled", locale: :es), response.body
  ensure
    Setting.set("chat_enabled", true)
  end

  test "a new message increments unread counters and broadcasts to the recipient" do
    sign_in @buyer

    assert_difference -> { @conversation.reload.seller_unread_count }, 1 do
      assert_turbo_stream_broadcasts [ @conversation, @seller ] do
        post conversation_messages_path(@conversation, locale: :es),
             params: { message: { body: "¿Sigue disponible?" } }
      end
    end

    assert_redirected_to conversation_path(@conversation, locale: :es, anchor: "conversation-messages")
    assert_equal @buyer, @conversation.messages.last.sender
  end

  test "opening a thread marks messages read and clears the counter" do
    sign_in @seller

    get conversation_path(@conversation, locale: :es)

    assert_response :success
    assert_equal 0, @conversation.reload.seller_unread_count
    assert @conversation.messages.first.reload.read?
  end

  test "mark all as read clears every conversation for the user" do
    @conversation.messages.create!(sender: @seller, body: "Te espero")
    sign_in @buyer
    assert_operator @conversation.reload.buyer_unread_count, :>, 0

    post inbox_read_all_path(locale: :es)

    assert_redirected_to conversations_path(locale: :es)
    assert_equal 0, @conversation.reload.buyer_unread_count
  end

  test "archive and unarchive toggle the participant view" do
    sign_in @buyer

    post conversation_archive_path(@conversation, locale: :es)
    assert @conversation.reload.archived_for?(@buyer)
    assert_not @conversation.archived_for?(@seller)

    delete conversation_archive_path(@conversation, locale: :es)
    assert_not @conversation.reload.archived_for?(@buyer)
  end

  test "blocking and unblocking a user from the thread" do
    sign_in @buyer

    assert_difference -> { @buyer.blocks_made.count }, 1 do
      post blocks_path(locale: :es), params: { user_id: @seller.id }
    end

    post conversation_messages_path(@conversation, locale: :es),
         params: { message: { body: "Hola" } }
    assert_equal I18n.t("messaging.errors.blocked", locale: :es), flash[:alert]

    block = @buyer.blocks_made.find_by(blocked: @seller)
    assert_difference -> { @buyer.blocks_made.count }, -1 do
      delete block_path(block, locale: :es)
    end
  end

  test "accepting an offer reserves the offer price on the cart item" do
    offer = @conversation.messages.create!(
      sender: @buyer, kind: :offer, offer_amount_cents: 40_000, body: "Te ofrezco 400"
    )
    sign_in @seller

    post message_offer_response_path(offer, locale: :es), params: { decision: "accept" }

    assert_redirected_to conversation_path(@conversation, locale: :es)
    assert offer.reload.offer_accepted?
    cart_item = CartItem.find_by(user: @buyer, listing: @listing)
    assert_equal 40_000, cart_item.offer_price_cents
    assert cart_item.offer_price_active?
  end

  test "countering declines the previous offer and creates a pending counter" do
    offer = @conversation.messages.create!(
      sender: @buyer, kind: :offer, offer_amount_cents: 40_000, body: "Te ofrezco 400"
    )
    sign_in @seller

    assert_difference -> { @conversation.messages.count }, 1 do
      post message_offer_response_path(offer, locale: :es),
           params: { decision: "counter", amount: "450" }
    end

    assert offer.reload.offer_declined?
    counter = @conversation.messages.order(:id).last
    assert counter.offer?
    assert counter.offer_pending?
    assert_equal @seller, counter.sender
    assert_equal 45_000, counter.offer_amount_cents
  end

  test "declining an offer notifies the sender" do
    offer = @conversation.messages.create!(
      sender: @buyer, kind: :offer, offer_amount_cents: 40_000, body: "Te ofrezco 400"
    )
    sign_in @seller

    assert_difference -> { @buyer.notifications.count }, 1 do
      post message_offer_response_path(offer, locale: :es), params: { decision: "decline" }
    end

    assert offer.reload.offer_declined?
  end

  test "offers below half the listing price are rejected" do
    sign_in @buyer

    assert_no_difference -> { @conversation.messages.count } do
      post conversation_offers_path(@conversation, locale: :es),
           params: { offer: { amount: "100" } }
    end

    assert_response :redirect
    assert flash[:alert].present?
  end

  test "following page lists stores the user follows with latest listings" do
    sign_in @buyer

    get followings_path(locale: :es)

    assert_response :success
    assert_match @seller.store.name, response.body
    assert_match @listing.title, response.body
  end

  test "senders are rate limited to thirty messages per ten minutes" do
    29.times do |index|
      @conversation.messages.create!(sender: @buyer, body: "Mensaje #{index}")
    end

    assert_no_difference -> { @conversation.messages.count } do
      @conversation.messages.create(sender: @buyer, body: "Uno más")
    end
    assert @conversation.messages.build(sender: @buyer, body: "Uno más").invalid?
  end
end
