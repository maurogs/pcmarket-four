class SellOfferMailer < ApplicationMailer
  helper ApplicationHelper

  def status(offer, event)
    @offer = offer
    @event = event.to_s
    @url = sell_offer_url(offer, locale: offer.user.locale)

    I18n.with_locale(offer.user.locale.presence || I18n.default_locale) do
      mail(
        to: offer.user.email,
        subject: t("sell_to_us.mailer.#{@event}.subject", item: offer.item_name,
                                                         site: Setting.get("site_name", "PCMarket"))
      )
    end
  end
end
