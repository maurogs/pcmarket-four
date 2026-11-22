module Api
  module V1
    class CategoriesController < BaseController
      def index
        @tree = Api::CategoryTree.call
        cache_public_read!(extra: Category.maximum(:updated_at))
        return if performed?

        render :index, formats: :json
      end

      def show
        @category = Category.active.friendly.find(params[:slug])
        @children = @category.children.active.order(:position, :id)
        @filters = @category.effective_filters
        @labels = Listing::LABELS.map { |key| { key: key, name: api_label_name(key) } }
        @count = Listing.visible.in_category(@category).count

        cache_public_read!(@category, extra: @count)
        return if performed?

        render :show, formats: :json
      end
    end
  end
end
