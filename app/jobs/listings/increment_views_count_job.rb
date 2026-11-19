module Listings
  # Bumps views_count off the request thread. Repeated views by the same
  # visitor (session id, falling back to remote IP for anonymous requests)
  # only count once per hour — the dedupe is the cache key.
  class IncrementViewsCountJob < ApplicationJob
    DEDUPE_TTL = 1.hour

    def self.dedupe_key_for(request)
      Digest::MD5.hexdigest("#{request.session.id}/#{request.remote_ip}")
    end

    def perform(listing_id, dedupe_key)
      Rails.cache.fetch("listings/viewed/#{listing_id}/#{dedupe_key}", expires_in: DEDUPE_TTL) do
        # Atomic counter — no validations/callbacks needed here.
        Listing.where(id: listing_id).update_all("views_count = views_count + 1") # rubocop:disable Rails/SkipsModelValidations
        true
      end
    end
  end
end
