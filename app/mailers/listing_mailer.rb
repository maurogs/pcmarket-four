class ListingMailer < ApplicationMailer
  helper ApplicationHelper

  def approved(listing, locale: nil)
    deliver(listing, :approved, locale: locale)
  end

  def rejected(listing, reason:, locale: nil)
    @reason = reason
    deliver(listing, :rejected, locale: locale)
  end

  private

  def deliver(listing, kind, locale: nil)
    @listing = listing
    @kind = kind
    @url = listing_url(listing, locale: locale || listing.user.locale)
    I18n.with_locale(locale.presence || listing.user.locale) do
      mail(to: listing.user.email,
           subject: t("admin.mailer.listing.#{kind}.subject", title: listing.title,
                                                              site: Setting.get("site_name", "PCMarket")))
    end
  end
end
