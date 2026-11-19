module LocaleHelper
  # Link to the current page in another locale (falls back to root).
  def locale_link(locale)
    url_for(locale: locale, only_path: true)
  end
end
