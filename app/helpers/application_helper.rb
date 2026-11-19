module ApplicationHelper
  # href of a curated mega-menu entry, with a search fallback (home links).
  def nav_entry_path(key, fallback = nil)
    NavigationMenu.items.find { |item| item.key == key.to_s }&.href ||
      fallback || search_path
  end

  def locale_label(locale)
    t("locales.#{locale}")
  end

  # Google sign-in is only shown once real credentials are configured.
  def google_oauth_enabled?
    ENV["GOOGLE_CLIENT_ID"].present? && ENV["GOOGLE_CLIENT_SECRET"].present?
  end
end
