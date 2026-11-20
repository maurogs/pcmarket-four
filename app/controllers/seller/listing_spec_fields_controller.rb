# Turbo Frame endpoint for the sell form's category-driven specification
# fields (Phase 3 step 2): GET /seller/listing_spec_fields?category_id=…
# with an optional listing_id so an existing draft's current values are
# re-rendered. The response is just the `listing_specs` frame (no layout);
# a foreign listing_id 404s instead of leaking another seller's specs.
module Seller
  class ListingSpecFieldsController < ApplicationController
    layout false
    before_action :authenticate_user!

    def show
      @category = Category.active.find_by(id: params[:category_id])
      @listing = nil
      return if params[:listing_id].blank?

      @listing = current_user.store&.listings&.find_by(id: params[:listing_id])
      render_not_found if @listing.nil?
    end
  end
end
