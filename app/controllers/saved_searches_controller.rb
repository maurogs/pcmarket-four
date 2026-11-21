class SavedSearchesController < ApplicationController
  before_action :authenticate_user!

  def index
    @saved_searches = current_user.saved_searches.includes(:category).order(created_at: :desc)
  end

  def create
    search = ListingSearch.new(params: search_params_from_query, category: category)
    saved_search = SavedSearch.build_from(user: current_user, search: search, name: params[:name])

    if saved_search.save
      redirect_to saved_searches_path, notice: t("saved_searches.created")
    else
      redirect_back fallback_location: root_path, alert: t("saved_searches.invalid")
    end
  end

  def update
    saved_search = current_user.saved_searches.find(params[:id])

    if saved_search.update(notify: !saved_search.notify)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "saved-search-#{saved_search.id}",
            partial: "saved_searches/saved_search",
            locals: { saved_search: saved_search }
          )
        end
        format.html { redirect_back fallback_location: saved_searches_path }
      end
    else
      redirect_back fallback_location: saved_searches_path, alert: t("saved_searches.invalid")
    end
  end

  def destroy
    current_user.saved_searches.find(params[:id]).destroy!
    redirect_to saved_searches_path, notice: t("saved_searches.destroyed")
  end

  private

  def search_params_from_query
    query = params[:search_query].to_s
    return ActionController::Parameters.new.permit! if query.blank?

    Rack::Utils.parse_nested_query(query)
  rescue StandardError
    {}
  end

  def category
    Category.find_by(id: params[:category_id]) if params[:category_id].present?
  end
end
