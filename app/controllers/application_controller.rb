class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include Pagy::Backend

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  around_action :switch_locale
  before_action :set_default_meta_tags
  before_action :complete_pending_favorite, if: :user_signed_in?
  before_action :configure_permitted_parameters, if: :devise_controller?

  helper_method :menu_categories, :primary_menu_categories, :more_menu_categories,
                :filters_applied?, :cart_summary

  SEARCH_PARAMS = %i[q min_price max_price free_shipping on_sale deals sort page seller
                     category_id include_sold].freeze
  SEARCH_ARRAY_PARAMS = %i[condition labels tags region_id shipping].freeze

  def search_params
    permitted = params.permit(*SEARCH_PARAMS, **SEARCH_ARRAY_PARAMS.index_with { [] })
    permitted[:f] = params[:f].to_unsafe_h if params[:f].present?
    permitted
  end

  def filters_applied?
    search_params.to_h.except("page", "sort").values.any?(&:present?)
  end

  def cart_summary
    @cart_summary ||= CartSummary.for(
      user: current_user,
      token: current_user ? nil : cookies.signed[:cart_token]
    )
  end

  def default_url_options
    { locale: I18n.locale }
  end

  def menu_categories
    @menu_categories ||= MenuBuilder.new(locale: I18n.locale).call
  end

  def primary_menu_categories
    menu_categories.first(MenuBuilder::PRIMARY_LIMIT)
  end

  def more_menu_categories
    menu_categories.drop(MenuBuilder::PRIMARY_LIMIT)
  end

  private

  def switch_locale(&action)
    locale = resolved_locale
    persist_preferred_locale(locale)
    I18n.with_locale(locale, &action)
  end

  def persist_preferred_locale(locale)
    return if params[:locale].blank?
    return unless user_signed_in?
    return if current_user.locale.to_s == locale.to_s

    current_user.update_column(:locale, locale.to_s)
  end

  def resolved_locale
    extract_locale || user_locale || browser_locale || I18n.default_locale
  end

  def extract_locale
    requested = params[:locale].to_s
    return nil if requested.blank?

    requested if available_locale?(requested)
  end

  def user_locale
    return nil unless user_signed_in?

    locale = current_user.locale.to_s
    locale if available_locale?(locale)
  end

  def browser_locale
    header = request.env["HTTP_ACCEPT_LANGUAGE"].to_s
    header.split(",").each do |entry|
      tag = entry.split(";").first.to_s.strip.downcase
      next if tag.blank?

      candidate = tag.split("-").first
      return candidate if available_locale?(candidate)
    end
    nil
  end

  def available_locale?(locale)
    I18n.available_locales.map(&:to_s).include?(locale.to_s)
  end

  def set_default_meta_tags
    canonical = "#{request.base_url}#{request.path}"
    description = t("layout.meta.description")
    image = "#{request.base_url}/og-default.png"

    og = {
      site_name: Setting.get("site_name", "PCMarket"),
      type: "website",
      title: t("layout.meta.title"),
      description: description,
      url: canonical,
      image: image,
      image_alt: t("layout.meta.og_image_alt")
    }
    twitter = {
      card: "summary_large_image",
      title: t("layout.meta.title"),
      description: description,
      image: image
    }

    set_meta_tags(
      site: Setting.get("site_name", "PCMarket"),
      title: t("layout.meta.title"),
      description: description,
      reverse: true,
      separator: " | ",
      canonical: canonical,
      alternate: alternate_urls,
      og: og,
      twitter: twitter
    )
  end

  def alternate_urls
    urls = I18n.available_locales.index_with do |locale|
      url_for(locale: locale, only_path: false)
    end
    urls.merge("x-default" => url_for(locale: I18n.default_locale, only_path: false))
  end

  def require_staff
    return if current_user&.staff?

    redirect_to root_path, alert: t("errors.not_authorized")
  end

  def user_not_authorized
    flash[:alert] = t("errors.not_authorized")
    redirect_back_or_to(root_path)
  end

  def complete_pending_favorite
    listing_id = session.delete(:pending_favorite_id)
    return if listing_id.blank?

    listing = Listing.find_by(id: listing_id)
    current_user.favorites.find_or_create_by!(listing: listing) if listing
  end

  def configure_permitted_parameters
    keys = %i[first_name last_name username email password password_confirmation
              terms_accepted accepts_marketing country_code locale]
    devise_parameter_sanitizer.permit(:sign_up, keys: keys)
    devise_parameter_sanitizer.permit(:account_update, keys: keys)
  end
end
