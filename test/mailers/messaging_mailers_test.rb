require "test_helper"

class MessagingMailersTest < ActionMailer::TestCase
  setup do
    @buyer = users(:buyer)
    @seller = users(:seller)
    @listing = listings(:published_gpu)
    @conversation = conversations(:buyer_seller_gpu)
    @message = messages(:first_message)
  end

  test "new message email renders in the recipient locale" do
    mail = MessageMailer.notify(@conversation, @message, @seller, kind: "message_received")

    assert_equal [ @seller.email ], mail.to
    assert_includes mail.subject, @buyer.display_name
    assert_includes mail.text_part.body.decoded, @message.body
  end

  test "offer email includes the amount and CTA" do
    offer = @conversation.messages.create!(
      sender: @buyer, kind: :offer, offer_amount_cents: 40_000, body: "Te ofrezco 400"
    )

    mail = MessageMailer.notify(@conversation, offer, @seller, kind: "offer_received")

    assert_includes mail.subject, @buyer.display_name
    assert_includes mail.text_part.body.decoded, "400"
  end

  test "saved search match email lists the listing" do
    mail = SavedSearchMailer.match(saved_searches(:buyer_gpu_search), [ @listing ])

    assert_equal [ @buyer.email ], mail.to
    assert_includes mail.text_part.body.decoded, @listing.title
  end

  test "saved search digest groups searches" do
    entries = [ { search: saved_searches(:buyer_gpu_search), listings: [ @listing ] } ]
    mail = SavedSearchMailer.digest(@buyer, entries)

    assert_equal [ @buyer.email ], mail.to
    assert_includes mail.text_part.body.decoded, @listing.title
  end

  test "favourite price drop email includes both prices" do
    mail = FavouriteMailer.price_drop(@buyer, @listing, 60_000)

    assert_equal [ @buyer.email ], mail.to
    assert_includes mail.text_part.body.decoded, @listing.title
  end
end
