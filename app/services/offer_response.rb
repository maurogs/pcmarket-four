# Applies the seller/buyer decision to a pending offer and keeps the cart in
# sync when an offer is accepted. Accepted offers create a reserved cart price
# valid for 24 hours.
class OfferResponse
  class Error < StandardError
    attr_reader :message_key

    def initialize(message_key)
      @message_key = message_key
      super(message_key)
    end
  end

  DECISIONS = %w[accept decline counter].freeze
  CART_OFFER_TTL = 24.hours

  def initialize(message:, actor:, decision:, amount_cents: nil)
    @message = message
    @actor = actor
    @decision = decision.to_s
    @amount_cents = amount_cents
  end

  def call
    raise Error, "invalid_decision" unless DECISIONS.include?(decision)
    raise Error, "not_participant" unless message.conversation.participant?(actor)
    raise Error, "own_offer" if message.sender_id == actor.id
    raise Error, "offer_not_pending" unless message.offer_pending?

    if message.offer_expired?
      message.expire!
      raise Error, "offer_expired"
    end

    case decision
    when "accept" then accept!
    when "decline" then decline!
    when "counter" then counter!
    end
  end

  private

  attr_reader :message, :actor, :decision, :amount_cents

  def conversation
    message.conversation
  end

  def accept!
    listing = conversation.listing
    raise Error, "listing_unavailable" if listing.blank?

    message.accept_offer!(actor)
    reserve_cart_price!(listing)
    notify!("offer_accepted", message.sender)
    message
  end

  def decline!
    message.decline_offer!(actor)
    notify!("offer_declined", message.sender)
    message
  end

  def counter!
    amount = amount_cents.to_i
    raise Error, "invalid_amount" unless amount.positive?

    message.decline_offer!(actor)
    counter = conversation.messages.new(
      sender: actor,
      kind: :offer,
      offer_amount_cents: amount,
      body: I18n.t("messaging.offers.counter_body",
                   amount: ApplicationController.helpers.format_price(amount))
    )
    counter.counter_to = message
    counter.save!
    counter
  end

  def reserve_cart_price!(listing)
    buyer = conversation.buyer
    cart_item = CartItem.find_or_initialize_by(user_id: buyer.id, listing_id: listing.id)
    cart_item.quantity = 1 if cart_item.new_record?
    cart_item.offer_price_cents = message.offer_amount_cents
    cart_item.offer_expires_at = CART_OFFER_TTL.from_now
    cart_item.save!
  end

  def notify!(kind, recipient)
    Notifier.call(
      recipient,
      kind,
      params: {
        conversation_id: conversation.id,
        listing: conversation.listing&.title.to_s,
        amount: message.offer_amount_cents
      },
      url: Rails.application.routes.url_helpers.conversation_path(
        conversation, locale: recipient.locale
      )
    )
    return unless recipient.notify_by_email?("email_offers")

    MessageMailer.notify(conversation, message, recipient, kind: kind).deliver_later
  end
end
