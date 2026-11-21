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

  helper_method :menu_categories

  def default_url_options
    { locale: I18n.locale }
  end

  def menu_categories
    @menu_categories ||= MenuBuilder.new(locale: I18n.locale).call
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
end
