# POST /seller/listings/:listing_id/sale — record an in-person sale: the
# listing goes sold (sold_at stamped), or simply loses one unit when there
# is stock left (Listing#record_offline_sale!). Only published/paused
# listings can be sold; anything else lands in the invalid-transition alert.
module Seller
  module Listings
    class SalesController < BaseController
      def create
        sold = @listing.record_offline_sale!

        if sold
          render_row notice: t(".sold")
        else
          render_row notice: t(".reduced", count: @listing.quantity)
        end
      end
    end
  end
end
