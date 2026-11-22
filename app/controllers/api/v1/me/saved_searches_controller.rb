module Api
  module V1
    module Me
      class SavedSearchesController < BaseController
        before_action :authenticate!

        def index
          scope = current_user.saved_searches.includes(:category).order(created_at: :desc)
          @saved_searches, @pagy = paginate(scope)
          render :index, formats: :json
        end

        def create
          search = ListingSearch.new(params: search_params, category: category)
          saved_search = SavedSearch.build_from(
            user: current_user,
            search: search,
            name: params.dig(:saved_search, :name) || params[:name]
          )

          if saved_search.save
            @saved_search = saved_search
            render :show, formats: :json, status: :created
          else
            render_saved_search_error(saved_search)
          end
        end

        def update
          saved_search = current_user.saved_searches.find(params[:id])

          if saved_search.update(saved_search_params)
            @saved_search = saved_search
            render :show, formats: :json
          else
            render_saved_search_error(saved_search)
          end
        end

        def destroy
          current_user.saved_searches.find(params[:id]).destroy!
          head :no_content
        end

        private

        def saved_search_params
          permitted = params.fetch(:saved_search, {}).permit(:name, :notify, :frequency).to_h
          permitted["frequency"] = nil unless SavedSearch.frequencies.key?(permitted["frequency"].to_s)
          permitted.compact
        end

        def search_params
          params.fetch(:saved_search, params).permit(
            :q, :min_price, :max_price, :category_id, :sort,
            { condition: [], labels: [], tags: [], region_id: [], shipping: [], f: {} }
          ).to_h
        end

        def category
          Category.find_by(id: params.dig(:saved_search, :category_id) || params[:category_id])
        end

        def render_saved_search_error(saved_search)
          render_error("validation_failed", t("api.errors.saved_search_invalid"),
                       status: :unprocessable_entity,
                       details: saved_search.errors.to_hash.transform_values { |messages| Array(messages) })
        end
      end
    end
  end
end
