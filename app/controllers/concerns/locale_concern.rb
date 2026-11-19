module LocaleConcern
  extend ActiveSupport::Concern

  AVAILABLE_LOCALES = I18n.available_locales.map(&:to_sym).freeze
  LOCALE_COOKIE = "pcmarket_locale".freeze
  LOCALE_PATTERN = /\A#{Regexp.union(AVAILABLE_LOCALES.map(&:to_s))}\z/.freeze

  included do
    before_action :set_locale
    helper_method :available_locales
  end

  private

  # Priority: URL param > cookie > Accept-Language header > default locale.
  def set_locale
    locale = extract_locale || I18n.default_locale
    I18n.locale = locale
    set_locale_cookie(locale)
  end

  def extract_locale
    normalized_locale(params[:locale]) ||
      normalized_locale(cookies.signed[LOCALE_COOKIE]) ||
      negotiated_locale
  end

  def negotiated_locale
    request.env["HTTP_ACCEPT_LANGUAGE"]&.then do |header|
      header.scan(/([a-z]{2})(?:-[a-z]{2})?/i).flatten.lazy
            .map { |code| normalized_locale(code) }
            .find(&:presence)
    end
  end

  def normalized_locale(candidate)
    candidate = candidate.to_s.downcase
    candidate.presence if LOCALE_PATTERN.match?(candidate)
  end

  def set_locale_cookie(locale)
    return if cookies.signed[LOCALE_COOKIE] == locale.to_s

    cookies.signed.permanent[LOCALE_COOKIE] = { value: locale.to_s, httponly: true }
  end

  def available_locales
    I18n.available_locales
  end
end
