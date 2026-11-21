class ListingsController < ApplicationController
  before_action :authenticate_user!, only: %i[new create edit update destroy]
  before_action :set_listing, only: %i[show edit update destroy]

  def index
    scope = Listing.visible.includes(:store, :category, { images_attachments: :blob }).recent
    scope = scope.search_text(params[:q]) if params[:q].present?
    @pagy, @listings = pagy(scope, limit: 24)
  end

  def show
    @spec_labels = FilterDefinition.where(key: @listing.specs.keys).index_by(&:key)
  end

  def new
  end

  def create
    redirect_to listings_path, notice: t("pages.coming_soon.default_body")
  end

  def edit
  end

  def update
    redirect_to listing_path(@listing), notice: t("pages.coming_soon.default_body")
  end

  def destroy
    redirect_to listings_path, notice: t("pages.coming_soon.default_body")
  end

  private

  def set_listing
    @listing = Listing.where(status: %i[published sold]).friendly.find(params[:id])
  end
end
