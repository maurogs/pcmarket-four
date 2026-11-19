module Stores
  # Recomputes the store's published-listing counter. Called from the
  # after-commit job; safe to call directly in seeds and tests.
  class RefreshActiveListingsCount
    def self.call(store)
      store.update_column(:active_listings_count, store.listings.published.count)
    end
  end
end
