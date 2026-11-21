class SellOfferExpiryJob < ApplicationJob
  queue_as :default

  def perform
    SellOffer.expiring.find_each do |offer|
      next unless offer.expire!

      SellOfferNotifier.call(offer, :expired)
    end
  end
end
