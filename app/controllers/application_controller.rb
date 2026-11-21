class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  around_action :switch_locale

  def default_url_options
    { locale: I18n.locale }
  end

  private

  def switch_locale(&action)
    I18n.with_locale(extract_locale || I18n.default_locale, &action)
  end

  def extract_locale
    requested = params[:locale].to_s
    return nil if requested.blank?

    requested if I18n.available_locales.map(&:to_s).include?(requested)
  end

  def user_not_authorized
    flash[:alert] = t("errors.not_authorized")
    redirect_back_or_to(root_path)
  end
end
