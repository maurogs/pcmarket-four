module Admin
  # Single entry point for admin listing moderation: approval, rejection and
  # featuring. Every call notifies the seller through Notifier and the
  # matching ListingMailer email, translated to the seller locale.
  class ListingModeration
    class << self
      def approve(listing, admin)
        return false unless listing.approve!(admin)

        notify(listing, "listing_approved")
        true
      end

      def reject(listing, admin, reason)
        return false if reason.to_s.strip.blank?
        return false unless listing.reject!(admin, reason.to_s.strip)

        Notifier.call(
          listing.user,
          "listing_rejected",
          params: { "listing_id" => listing.id, "title" => listing.title,
                    "reason" => reason.to_s.strip },
          url: listing_path_for(listing)
        )
        true
      end

      def feature(listing, days)
        return false unless days.to_i.positive?

        listing.update!(
          featured_until: [ listing.featured_until, Time.current ].compact.max + days.to_i.days,
          labels: (listing.labels + [ "featured" ]).uniq
        )
        true
      end

      def unfeature(listing)
        listing.update!(
          featured_until: nil,
          labels: listing.labels - [ "featured" ]
        )
        true
      end

      private

      def notify(listing, kind)
        Notifier.call(
          listing.user,
          kind,
          params: { "listing_id" => listing.id, "title" => listing.title },
          url: listing_path_for(listing)
        )
      end

      def listing_path_for(listing)
        Rails.application.routes.url_helpers.listing_path(
          listing, locale: listing.user.locale.presence || I18n.default_locale
        )
      rescue StandardError
        nil
      end
    end
  end
end
