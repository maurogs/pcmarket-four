# POST / DELETE /seller/listings/:listing_id/pause — hide a published
# listing from the catalog (pause) or bring it back online (destroy =
# resume). Listings in any other state raise AASM::InvalidTransition, which
# the base controller turns into a friendly alert.
module Seller
  module Listings
    class PausesController < BaseController
      def create
        @listing.pause!
        render_row notice: t(".paused")
      end

      def destroy
        @listing.resume!
        render_row notice: t(".resumed")
      end
    end
  end
end
