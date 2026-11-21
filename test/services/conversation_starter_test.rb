require "test_helper"

class ConversationStarterTest < ActiveSupport::TestCase
  setup do
    @buyer = users(:buyer)
    @seller = users(:seller)
    @listing = listings(:published_gpu)
  end

  test "reuses the existing conversation for the same listing and participants" do
    conversation = conversations(:buyer_seller_gpu)

    assert_no_difference -> { Conversation.count } do
      result = ConversationStarter.new(user: @buyer, listing: @listing, body: "Hola").call
      assert_equal conversation, result
    end
  end

  test "rejects messaging yourself" do
    error = assert_raises(ConversationStarter::Error) do
      ConversationStarter.new(user: @seller, listing: @listing).call
    end

    assert_equal "own_listing", error.message_key
  end

  test "rejects a conversation when either party blocked the other" do
    Block.create!(blocker: @seller, blocked: @buyer)

    error = assert_raises(ConversationStarter::Error) do
      ConversationStarter.new(user: @buyer, listing: @listing).call
    end

    assert_equal "blocked", error.message_key
  end

  test "rejects new conversations when chat is disabled" do
    Setting.set("chat_enabled", false)

    error = assert_raises(ConversationStarter::Error) do
      ConversationStarter.new(user: @buyer, listing: @listing).call
    end

    assert_equal "chat_disabled", error.message_key
  ensure
    Setting.set("chat_enabled", true)
  end

  test "creates a seller-only conversation from a store" do
    conversation = ConversationStarter.new(user: @buyer, store: @seller.store).call

    assert_nil conversation.listing
    assert_equal @seller, conversation.seller
    assert_equal @buyer, conversation.buyer
  end

  test "creates the first message and flags unsafe content" do
    conversation = ConversationStarter.new(
      user: @buyer, listing: @listing, body: "Págame por Bizum al 612 345 678"
    ).call

    message = conversation.messages.last
    assert message.flagged?
    assert_equal @buyer, message.sender
  end
end
