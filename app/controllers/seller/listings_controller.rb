# Seller listing manager: /:locale/seller/listings. Everything is scoped to
# current_user.store — other sellers' listings 404. First-time sellers get
# their store created lazily (Stores::EnsureForUser) on new/create so the
# header's "List an item" button never dead-ends. create always saves a
# draft; update saves and, with the form's "Save & submit" button
# (submit_for_review=1), also submits for review through Listings::Submitter
# — the lifecycle endpoints themselves live under Seller::Listings::*. A
# published listing edited here goes back to pending_review through the
# model's own re-review logic.
module Seller
  class ListingsController < ApplicationController
    before_action :authenticate_user!
    before_action :ensure_store, only: %i[new create]
    before_action :set_store, except: %i[new create]
    before_action :set_listing, only: %i[edit update destroy]

    def index
      @status = params[:status].presence_in(Listing::STATUSES) || "draft"
      @counts = @store ? Listing.status_counts(@store) : Listing::STATUSES.index_with(0)
      @listings =
        if @store
          @store.listings.where(status: @status).includes(:category).order(updated_at: :desc)
        else
          Listing.none
        end
    end

    def new
      @listing = @store.listings.new(store_defaults)
    end

    def create
      @listing = @store.listings.new(listing_params)

      if @listing.save
        redirect_to edit_seller_listing_path(@listing), notice: t(".success")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @listing.update(listing_params)
        if params[:submit_for_review].present?
          submit_for_review
        else
          redirect_to edit_seller_listing_path(@listing), notice: t(".success")
        end
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @listing.deletable?
        @listing.destroy!
        redirect_to seller_listings_path, notice: t(".destroyed")
      else
        @listing.archive!
        redirect_to seller_listings_path, notice: t(".archived")
      end
    end

    private

    def ensure_store
      @store = Stores::EnsureForUser.call(current_user)
    end

    def set_store
      @store = current_user.store
    end

    # find_by_param also resolves historical slugs (whose fallback lookup
    # escapes the store scope), so re-check ownership before rendering.
    def set_listing
      @listing = @store&.listings&.find_by_param(params[:id])
      render_not_found unless @listing && @listing.store_id == @store.id
    end

    # The sell form's "Save & submit" button posts the fields plus
    # submit_for_review=1; the same Listings::Submitter the submissions
    # controller uses runs right after the save.
    def submit_for_review
      result = ::Listings::Submitter.call(@listing)

      if result.success?
        redirect_to edit_seller_listing_path(@listing), notice: t(".submitted")
      else
        redirect_to edit_seller_listing_path(@listing), alert: result.errors.to_sentence
      end
    end

    # Draft defaults copied from the seller's store settings.
    def store_defaults
      {
        allow_offers: @store.allow_offers_default,
        province: @store.province,
        city: @store.city,
        postal_code: @store.postal_code
      }
    end

    def listing_params
      permitted = params.expect(listing: %i[category_id title description price original_price
                                            quantity condition shipping_method shipping_price
                                            free_shipping ships_within_days local_pickup
                                            province city postal_code allow_offers
                                            image_order] +
                                [ { specs: {}, images: [], remove_image_ids: [] } ])
      # specs is an arbitrary { key => value | [values] } hash; the model
      # filters it down to the category's known definitions and values.
      if permitted[:specs].present?
        category = Category.find_by(id: permitted[:category_id]) || @listing&.category
        permitted[:specs] = Listing.sanitize_specs(category, permitted[:specs])
      end
      permitted
    end
  end
end
