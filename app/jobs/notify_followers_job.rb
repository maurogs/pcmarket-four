class NotifyFollowersJob < ApplicationJob
  queue_as :default

  def perform(listing_id)
    listing = Listing.find_by(id: listing_id)
    return if listing.blank? || listing.store.blank? || !listing.visible?

    listing.store.followers.find_each do |user|
      next if user.id == listing.user_id || user.deleted?

      Notifier.call(
        user,
        "followed_store_listing",
        params: { listing_id: listing.id, listing: listing.title, store: listing.store.name },
        url: Rails.application.routes.url_helpers.listing_path(listing, locale: user.locale)
      )
    end
  end
end
