module Api
  module V1
    class ListingsController < BaseController
      before_action :authenticate!, only: %i[create update destroy]
      before_action :set_listing, only: %i[show update destroy]

      SEARCH_PARAMS = [
        :q, :category, :min_price, :max_price, :seller, :sort, :page, :per_page,
        :free_shipping, :on_sale, :deals, :category_id,
        { condition: [], labels: [], tags: [], region_id: [], shipping: [], f: {} }
      ].freeze

      def index
        @search = ListingSearch.new(params: search_params, category: resolved_category)
        @search.result

        per_page = params[:per_page].to_i
        per_page = ListingSearch::PER_PAGE if per_page <= 0
        per_page = [ per_page, 100 ].min
        pages = [ (@search.total_count.to_f / per_page).ceil, 1 ].max
        page = [ [ params[:page].to_i, 1 ].max, pages ].min
        @pagy = Pagy.new(count: @search.total_count, page: page, limit: per_page)
        @listings = @search.relation.offset(@pagy.offset).limit(@pagy.limit).to_a

        cache_public_read!(extra: @search.digest)
        return if performed?

        render :index, formats: :json
      end

      def show
        raise ActiveRecord::RecordNotFound unless @listing.viewable_by?(current_user)

        cache_public_read!(@listing)
        return if performed?

        render :show, formats: :json
      end

      def create
        @listing = current_user.listings.new(
          country_code: current_user.country_code.presence || "ES"
        )
        authorize @listing

        save_listing
      end

      def update
        authorize @listing
        save_listing
      end

      def destroy
        authorize @listing

        if @listing.order_items.exists?
          @listing.update!(status: :archived)
        else
          @listing.destroy!
        end

        head :no_content
      end

      private

      def set_listing
        @listing = Listing.friendly.find(params[:slug])
      end

      def save_listing
        newly_created = @listing.new_record?
        form = ListingForm.new(
          listing: @listing,
          params: listing_form_params,
          submit: truthy?(params[:submit])
        )

        if form.save
          @listing.reload
          render :show, formats: :json, status: (newly_created ? :created : :ok)
        else
          @error_details = @listing.errors.to_hash.transform_values { |messages| Array(messages) }
          render_error("validation_failed", t("api.errors.validation_failed"),
                       status: :unprocessable_entity, details: @error_details)
        end
      end

      def listing_form_params
        permitted = params.require(:listing).permit(
          :category_id, :title, :brand, :model_name_text, :condition, :quantity,
          :description, :price, :original_price, :accepts_offers, :shipping_available,
          :free_shipping, :shipping_price, :ships_within_days, :local_pickup,
          :region_id, :city, :postal_code,
          tags: [], images: [], specs: {}
        )
        permitted.to_h.symbolize_keys
      end

      def search_params
        params.permit(*SEARCH_PARAMS).to_h
      end

      def resolved_category
        value = params[:category].presence || params[:category_slug].presence
        return nil if value.blank?

        slugs = value.to_s.split("/")
        Category.find_by_path_slugs(slugs) || Category.active.friendly.find(value)
      rescue ActiveRecord::RecordNotFound
        nil
      end
    end
  end
end
