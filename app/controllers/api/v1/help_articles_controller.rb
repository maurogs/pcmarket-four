module Api
  module V1
    class HelpArticlesController < BaseController
      def index
        scope = HelpArticle.published
        if params[:category].present? && HelpArticle::CATEGORIES.include?(params[:category].to_s)
          scope = scope.for_category(params[:category])
        end
        scope = HelpArticle.search(params[:q]) if params[:q].present?
        @articles, @pagy = paginate(scope.ordered)

        cache_public_read!(extra: [ @pagy.count, params[:q], params[:category] ])
        return if performed?

        render :index, formats: :json
      end

      def show
        @article = HelpArticle.published.find_by!(slug: params[:slug])

        cache_public_read!(@article)
        return if performed?

        render :show, formats: :json
      end
    end
  end
end
