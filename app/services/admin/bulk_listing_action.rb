module Admin
  # Applies one whitelisted bulk action to the selected listings.
  class BulkListingAction
    ACTIONS = %w[approve reject pause archive delete add_label remove_label
                 feature unfeature].freeze

    attr_reader :processed

    def initialize(admin:, ids:, action:, label: nil, days: nil, reason: nil)
      @admin = admin
      @ids = Array(ids).map(&:to_i).reject(&:zero?)
      @action = action.to_s
      @label = label.to_s
      @days = days.to_i
      @reason = reason.presence
      @processed = []
    end

    def call
      return [] unless ACTIONS.include?(@action)
      return [] if @ids.empty?

      Listing.where(id: @ids).includes(:user).find_each do |listing|
        @processed << listing if perform(listing)
      end
      @processed
    end

    def count
      processed.size
    end

    private

    attr_reader :admin, :action, :label, :days, :reason

    def perform(listing)
      case action
      when "approve" then Admin::ListingModeration.approve(listing, admin)
      when "reject" then reject(listing)
      when "pause" then listing.pause!
      when "archive" then listing.update(status: :archived) || true
      when "delete" then remove(listing)
      when "add_label" then add_label(listing)
      when "remove_label" then remove_label(listing)
      when "feature" then Admin::ListingModeration.feature(listing, days)
      when "unfeature" then Admin::ListingModeration.unfeature(listing)
      end
    end

    def reject(listing)
      Admin::ListingModeration.reject(
        listing, admin, reason || I18n.t("admin.moderation.reasons.other")
      )
    end

    def add_label(listing)
      return false unless Listing::LABELS.include?(label)

      listing.update(labels: (listing.labels + [ label ]).uniq)
    end

    def remove_label(listing)
      return false unless Listing::LABELS.include?(label)

      listing.update(labels: listing.labels - [ label ])
    end

    def remove(listing)
      if listing.order_items.exists?
        listing.update!(status: :archived)
      else
        listing.destroy!
      end
      true
    end
  end
end
