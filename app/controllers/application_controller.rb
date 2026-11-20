class ApplicationController < ActionController::Base
  include LocaleConcern
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_current_attributes
  before_action :configure_permitted_parameters, if: :devise_controller?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def set_current_attributes
    Current.user = current_user if respond_to?(:current_user)
    Current.country ||= resolve_current_country
  end

  # The active market: cookie choice wins, then the locale's country,
  # falling back to any enabled market.
  def resolve_current_country
    Country.enabled.find_by(code: cookies.signed["pcmarket_country"]) ||
      Country.enabled.find_by(default_locale: I18n.locale) ||
      Country.enabled.first
  end

  def configure_permitted_parameters
    signup_fields = [ :username, :first_name, :last_name, :phone, :locale, :country_id ]
    account_fields = signup_fields + [ :avatar ]
    devise_parameter_sanitizer.permit(:sign_up, keys: signup_fields)
    devise_parameter_sanitizer.permit(:account_update, keys: account_fields)
  end

  def user_not_authorized
    redirect_to(root_path, alert: t("errors.forbidden"))
  end

  # Shared 404 for controllers that scope lookups to the current user and
  # come up empty (instead of leaking existence with a 403).
  def render_not_found
    render file: Rails.public_path.join("404.html"), status: :not_found, layout: false
  end
end
