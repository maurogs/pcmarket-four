class SavedSearchMailer < ApplicationMailer
  helper ApplicationHelper

  def match(saved_search, listings)
    @saved_search = saved_search
    @listings = listings
    @user = saved_search.user

    I18n.with_locale(locale_for(@user)) do
      @url = saved_search_url_for(@saved_search)
      mail(to: @user.email,
           subject: t("messaging.mailer.saved_search_match.subject", search: @saved_search.name))
    end
  end

  def digest(user, entries)
    @user = user
    @entries = entries

    I18n.with_locale(locale_for(user)) do
      @url = saved_searches_url(locale: locale_for(user))
      mail(to: user.email, subject: t("messaging.mailer.saved_search_digest.subject"))
    end
  end

  private

  def saved_search_url_for(saved_search)
    saved_searches_url(locale: locale_for(saved_search.user))
  end

  def locale_for(user)
    candidate = user.locale.to_s
    I18n.available_locales.map(&:to_s).include?(candidate) ? candidate : I18n.default_locale
  end
end
