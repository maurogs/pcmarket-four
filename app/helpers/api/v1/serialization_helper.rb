module Api
  module V1
    module SerializationHelper
      THUMB_SIZE = [ 640, 480 ].freeze
      LARGE_SIZE = [ 1600, 1200 ].freeze

      def api_money(cents, currency = "EUR")
        amount = cents.to_i / 100.0
        {
          cents: cents.to_i,
          currency: currency,
          formatted: format("%.2f %s", amount, currency)
        }
      end

      def api_image_urls(attachment)
        routes = Rails.application.routes.url_helpers
        url_options = { host: request.host_with_port, protocol: request.protocol }
        thumb = attachment.variant(resize_to_limit: THUMB_SIZE, convert: "webp")
        large = attachment.variant(resize_to_limit: LARGE_SIZE, convert: "webp")

        {
          id: attachment.id,
          position: attachment.blob.metadata["position"].to_i,
          content_type: attachment.blob.content_type,
          byte_size: attachment.blob.byte_size,
          url: routes.rails_blob_url(attachment.blob, **url_options),
          thumb_url: routes.rails_representation_url(thumb, **url_options),
          large_url: routes.rails_representation_url(large, **url_options)
        }
      end

      def api_listing_images(listing)
        listing.ordered_images.map { |attachment| api_image_urls(attachment) }
      end

      def api_avatar_url(user)
        return nil unless user&.avatar&.attached?

        routes = Rails.application.routes.url_helpers
        routes.rails_blob_url(user.avatar.blob, host: request.host_with_port, protocol: request.protocol)
      end

      def api_store_logo_url(store)
        return nil unless store&.logo&.attached?

        routes = Rails.application.routes.url_helpers
        routes.rails_blob_url(store.logo.blob, host: request.host_with_port, protocol: request.protocol)
      end

      def api_store_banner_url(store)
        return nil unless store&.banner&.attached?

        routes = Rails.application.routes.url_helpers
        routes.rails_blob_url(store.banner.blob, host: request.host_with_port, protocol: request.protocol)
      end

      def api_label_name(key)
        I18n.t("listings.labels.#{key}", default: key.to_s)
      end

      def api_tag_name(key)
        I18n.t("listings.tags.#{key}", default: key.to_s)
      end

      def api_condition_name(key)
        I18n.t("activerecord.enums.listing.condition.#{key}", default: key.to_s.humanize)
      end

      def api_filter_payload(definition)
        {
          key: definition.key,
          name: definition.name,
          input_type: definition.input_type,
          unit: definition.unit,
          options: definition.filter_options.map { |option| { value: option.value, label: option.label } }
        }
      end
    end
  end
end
