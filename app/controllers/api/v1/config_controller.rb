module Api
  module V1
    class ConfigController < BaseController
      FEATURE_FLAGS = %w[
        checkout_enabled chat_enabled sell_to_us_enabled featured_listings_enabled
        reviews_enabled registrations_enabled
      ].freeze

      def show
        @site_name = Setting.get("site_name")
        @countries = Country.enabled.includes(:regions).order(:code)
        @locales = I18n.available_locales.map(&:to_s)
        @features = FEATURE_FLAGS.index_with { |key| Setting.enabled?(key) }
        @conditions = Listing.conditions.keys.map { |key| { key: key, name: api_condition_name(key) } }
        @labels = Listing::LABELS.map { |key| { key: key, name: api_label_name(key) } }
        @tags = Listing::TAGS.map { |key| { key: key, name: api_tag_name(key) } }
        @payment_methods = Payments::Availability.new(nil).options
        @min_app_version = Setting.get("api_min_app_version", "1.0.0")

        cache_public_read!(extra: [ @site_name, @min_app_version, Country.maximum(:updated_at) ])
        return if performed?

        render :show, formats: :json
      end
    end
  end
end
