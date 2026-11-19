module Stores
  class RefreshCountersJob < ApplicationJob
    queue_as :default

    def perform(store_id)
      store = Store.find_by(id: store_id)
      return if store.nil?

      RefreshActiveListingsCount.call(store)
    end
  end
end
