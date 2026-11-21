class CleanupSpecKeyJob < ApplicationJob
  queue_as :default

  def perform(filter_key)
    Listing.where("specs ? :key", key: filter_key).find_each do |listing|
      listing.update_columns(specs: listing.specs.except(filter_key), updated_at: Time.current)
    end
    ListingSearch.bust_caches!
  end
end
