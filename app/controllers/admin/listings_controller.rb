module Admin
  class ListingsController < BaseController
    before_action :set_listing, only: %i[show edit update destroy]

    def index
      authorize_admin!(Listing, :index?)

      @query = Admin::ListingQuery.new(filter_params)
      @listings = @query.call
      @pagy, @listings = pagy(@listings, limit: pagination_limit)
      @categories = Category.roots.order(:position)
    end

    def show
      authorize_admin!(@listing, :show?)
      @flags = Admin::ListingFlags.call(@listing)
      @orders = @listing.order_items.includes(order: %i[buyer seller]).map(&:order).compact.uniq
      @reports = Report.where(reportable: @listing).includes(:reporter).order(created_at: :desc)
      @audit_logs = AdminAuditLog.where(auditable: @listing).includes(:admin).recent.limit(30)
    end

    def edit
      authorize_admin!(@listing, :update?)
      @filters = @listing.category.effective_filters
    end

    def update
      authorize_admin!(@listing, :update?)

      updater = Admin::ListingUpdate.new(@listing, listing_params)
      if updater.call
        audit!("listing.updated", @listing)
        redirect_to admin_listing_path(@listing), notice: t("admin.listings.updated")
      else
        @filters = @listing.category.effective_filters
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize_admin!(@listing, :destroy?)

      if @listing.order_items.exists?
        @listing.update!(status: :archived)
        audit!("listing.archived", @listing, changeset: { "status" => [ "previous", "archived" ] })
      else
        @listing.destroy!
        audit!("listing.deleted", @listing, changeset: { "title" => @listing.title })
      end

      redirect_to admin_listings_path, notice: t("admin.listings.destroyed"), status: :see_other
    end

    private

    def set_listing
      @listing = Listing.includes(:user, :store, :category, images_attachments: :blob)
                        .friendly.find(params[:id])
    end

    def filter_params
      params.permit(:q, :status, :category_id, :seller, :country, :min_price, :max_price,
                    :featured, :flagged, :created_from, :created_to, :sort, :direction,
                    labels: [])
    end

    def listing_params
      params.require(:listing).permit(
        :title, :description, :category_id, :brand, :model_name_text, :condition,
        :quantity, :country_code, :region_id, :city, :postal_code,
        :shipping_available, :local_pickup, :free_shipping, :ships_within_days,
        :accepts_offers, :featured_until, :performance_score, :status,
        :price, :original_price, :shipping_price, :game_fps_json,
        labels: [], tags: [], specs: {}
      )
    end
  end
end
