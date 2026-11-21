class FavouriteMailer < ApplicationMailer
  helper ApplicationHelper

  def price_drop(user, listing, previous_price_cents)
    @user = user
    @listing = listing
    @previous_price_cents = previous_price_cents

    I18n.with_locale(locale_for(user)) do
      @url = listing_url(listing, locale: locale_for(user))
      mail(to: user.email,
           subject: t("messaging.mailer.price_drop.subject", listing: listing.title))
    end
  end

  private

  def locale_for(user)
    candidate = user.locale.to_s
    I18n.available_locales.map(&:to_s).include?(candidate) ? candidate : I18n.default_locale
  end
end
