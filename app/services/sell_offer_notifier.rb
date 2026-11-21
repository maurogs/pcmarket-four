class SellOfferNotifier
  EVENTS = %i[offered accepted declined received paid rejected expired].freeze

  def self.call(offer, event)
    new(offer, event).call
  end

  def initialize(offer, event)
    @offer = offer
    @event = event.to_sym
  end

  def call
    return unless EVENTS.include?(@event)

    Notification.create!(
      user: @offer.user,
      kind: "sell_offer_#{@event}",
      params: { item: @offer.item_name, amount: format_price(@offer.offered_price_cents) },
      url: Rails.application.routes.url_helpers.sell_offer_path(@offer, locale: @offer.user.locale)
    )
    SellOfferMailer.status(@offer, @event).deliver_later
  end

  private

  def format_price(cents)
    ActionController::Base.helpers.number_to_currency(cents.to_i / 100.0, unit: "€", precision: 0)
  end
end
