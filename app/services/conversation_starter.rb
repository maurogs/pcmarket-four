# Starts (or reuses) a conversation and enforces the messaging rules:
# chat enabled, no self-messaging, no blocks in either direction, and one
# thread per [listing, buyer, seller].
class ConversationStarter
  class Error < StandardError
    attr_reader :message_key

    def initialize(message_key)
      @message_key = message_key
      super(message_key)
    end
  end

  attr_reader :conversation

  def initialize(user:, listing: nil, seller: nil, store: nil, body: nil, offer_amount_cents: nil)
    @user = user
    @listing = listing
    @seller = resolve_seller(seller, store)
    @body = body.to_s.strip
    @offer_amount_cents = offer_amount_cents
  end

  def call
    raise Error, "chat_disabled" unless Setting.enabled?("chat_enabled")
    raise Error, "seller_missing" if seller.blank?
    raise Error, "own_listing" if seller.id == user.id
    raise Error, "blocked" if Block.between?(user, seller)
    raise Error, "listing_unavailable" if listing.present? && !listing.viewable_by?(user)

    conversation = find_or_create_conversation
    create_first_message(conversation)
    conversation
  end

  private

  attr_reader :user, :listing, :seller, :body, :offer_amount_cents

  def resolve_seller(seller, store)
    return listing.user if listing.present?
    return store.user if store.present?
    return seller if seller.is_a?(User)

    User.find_by(id: seller)
  end

  def find_or_create_conversation
    existing = Conversation.find_by(buyer_id: user.id, seller_id: seller.id, listing_id: listing&.id)
    return existing if existing

    Conversation.create!(buyer_id: user.id, seller_id: seller.id, listing_id: listing&.id)
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def create_first_message(conversation)
    return if body.blank? && offer_amount_cents.blank?

    attributes = { conversation: conversation, sender: user, body: body }
    if offer_amount_cents.present?
      attributes[:kind] = :offer
      attributes[:offer_amount_cents] = offer_amount_cents
      attributes[:body] = body.presence || I18n.t("messaging.offers.default_body",
                                                  amount: ApplicationController.helpers.format_price(offer_amount_cents))
    end

    conversation.messages.create!(attributes)
  end
end
