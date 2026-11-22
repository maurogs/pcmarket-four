class ApplicationMailer < ActionMailer::Base
  default from: "PCMarket <no-reply@pcmarket.es>"
  layout "mailer"

  before_action :skip_delivery_when_seeding

  private

  def skip_delivery_when_seeding
    return unless Current.seeding

    message.perform_deliveries = false
  end
end
