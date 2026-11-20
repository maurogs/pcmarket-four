# POST /seller/listings/:listing_id/submission — submit a draft or rejected
# listing for review (straight to published when the listing_auto_approve
# setting is on). Failures come back as an alert listing the messages: a
# toast for Turbo; for plain HTML a validation failure (missing photos,
# required specs) redirects to the edit page so the seller can fix it, an
# invalid transition (wrong state) back to the index.
module Seller
  module Listings
    class SubmissionsController < BaseController
      def create
        result = ::Listings::Submitter.call(@listing)

        if result.success?
          render_row notice: t(".submitted")
        else
          redirect = result.invalid_transition? ? seller_listings_path : edit_seller_listing_path(@listing)
          render_row_alert result.errors.to_sentence, redirect: redirect
        end
      end
    end
  end
end
