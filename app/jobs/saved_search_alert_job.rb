class SavedSearchAlertJob < ApplicationJob
  queue_as :default

  def perform(listing_id)
    return unless Setting.enabled?("saved_search_alerts_enabled")

    listing = Listing.find_by(id: listing_id)
    return if listing.blank? || !listing.visible?

    SavedSearch.prefilter_for(listing).instant.includes(:category).find_each do |saved_search|
      next unless saved_search.matches?(listing)

      deliver(saved_search, listing)
    end
  end

  private

  def deliver(saved_search, listing)
    user = saved_search.user
    return if user.blank? || user.deleted?

    Notifier.call(
      user,
      "saved_search_match",
      params: { search: saved_search.name, listing: listing.title, listing_id: listing.id },
      url: Rails.application.routes.url_helpers.listing_path(listing, locale: user.locale)
    )

    if user.notify_by_email?("email_saved_search_alerts")
      SavedSearchMailer.match(saved_search, [ listing ]).deliver_later
    end

    saved_search.update_column(:last_notified_at, Time.current)
  end
end
