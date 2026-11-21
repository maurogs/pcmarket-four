class ExpireOffersJob < ApplicationJob
  queue_as :default

  def perform
    Message.expired_offers.find_each(&:expire!)
  end
end
