class PriceDropAlertJob < ApplicationJob
  queue_as :default

  def perform(listing_id, previous_price_cents)
    listing = Listing.find_by(id: listing_id)
    return if listing.blank? || !listing.visible?

    listing.favorites.includes(:user).find_each do |favorite|
      user = favorite.user
      next if user.blank? || user.deleted? || user.id == listing.user_id

      Notifier.call(
        user,
        "price_drop_favourite",
        params: {
          listing_id: listing.id,
          listing: listing.title,
          old_price: previous_price_cents,
          price: listing.price_cents
        },
        url: Rails.application.routes.url_helpers.listing_path(listing, locale: user.locale)
      )

      next unless user.notify_by_email?("email_price_drops_favourites")

      FavouriteMailer.price_drop(user, listing, previous_price_cents).deliver_later
    end
  end
end
