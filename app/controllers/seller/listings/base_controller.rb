# Shared plumbing for the listing lifecycle actions (submission / pause /
# sale, Phase 3 step 4). Everything is scoped to current_user.store — other
# sellers' listings 404 — and AASM::InvalidTransition becomes a friendly
# alert instead of a 500. Turbo gets a stream that replaces the index row
# (dom_id target, see seller/listings/row_update) plus the toast area;
# plain HTML falls back to a redirect.
module Seller
  module Listings
    class BaseController < ApplicationController
      before_action :authenticate_user!
      before_action :set_listing

      rescue_from AASM::InvalidTransition, with: :handle_invalid_transition

      private

      # find_by_param also resolves historical slugs (whose fallback lookup
      # escapes the store scope), so re-check ownership before rendering
      # (same guard as Seller::ListingsController).
      def set_listing
        store = current_user.store
        @listing = store&.listings&.find_by_param(params[:listing_id])
        render_not_found unless @listing && @listing.store_id == store.id
      end

      # Success: re-render the index row (its action buttons changed) and the
      # flash for Turbo, or send the seller back to the index for HTML.
      def render_row(notice:)
        respond_to do |format|
          format.turbo_stream do
            flash.now[:notice] = notice
            @listing.reload
            render "seller/listings/row_update", locals: { listing: @listing }
          end
          format.html { redirect_to seller_listings_path, notice: notice }
        end
      end

      # Failure: the row stays as it is, only the alert is shown. HTML goes
      # back to `redirect:` with the message.
      def render_row_alert(message, redirect:)
        respond_to do |format|
          format.turbo_stream do
            flash.now[:alert] = message
            render "seller/listings/row_update", locals: { listing: @listing }
          end
          format.html { redirect_to redirect, alert: message }
        end
      end

      def handle_invalid_transition
        render_row_alert t("seller.listings.invalid_transition"), redirect: seller_listings_path
      end
    end
  end
end
