class HomeController < ApplicationController
  def index
    @feed = HomeFeed.new(locale: I18n.locale)
    @recently_viewed = recently_viewed_listings
  end

  private

  def recently_viewed_listings
    ids = Array(session[:viewed_listing_ids]).reverse.first(12)
    return [] if ids.empty?

    found = Listing.visible
                   .includes(:store, :category, :region, :user, { images_attachments: :blob })
                   .where(id: ids).index_by(&:id)
    ids.filter_map { |id| found[id] }
  end
end
