# GET /l/:id — listing detail. Only publicly visible listings answer for
# anonymous visitors; owners and admins see everything with a status banner.
class ListingsController < ApplicationController
  include Browseable

  before_action :set_listing

  def show
    return redirect_to(listing_path(@listing), status: :moved_permanently) if outdated_slug?

    unless @listing.viewable_by?(current_user)
      render_not_found
      return
    end

    anonymous_cacheable = !user_signed_in? && @listing.visible_to_public?
    fresh_when(last_modified: @listing.updated_at, etag: [ @listing, I18n.locale ]) if anonymous_cacheable
    Listings::IncrementViewsCountJob.perform_later(@listing.id, Listings::IncrementViewsCountJob.dedupe_key_for(request)) if anonymous_cacheable

    @similar_listings = Listing.similar_to(@listing)
    @more_from_store = Listing.more_from_store(@listing)
  end

  private

  def set_listing
    @listing = Listing.find_by_param(params[:id])
    render_not_found unless @listing
  end

  # FriendlyId history: old slugs 301 to the canonical one.
  def outdated_slug?
    @listing.slug != params[:id].to_s
  end
end
