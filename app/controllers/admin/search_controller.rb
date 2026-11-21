module Admin
  class SearchController < BaseController
    def index
      authorize_admin!(:search, :search?)

      @query = params[:q].to_s.strip
      @results = Admin::GlobalSearch.new(@query).call
    end
  end
end
