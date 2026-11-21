module Admin
  class CategoriesController < BaseController
    before_action :set_category, only: %i[show edit update destroy]

    def index
      authorize_admin!(Category, :index?)

      @categories = Category.order(:position, :id).to_a
      @roots = @categories.select(&:is_root?)
      @children_by_parent = @categories.reject(&:is_root?).group_by { |category| category.parent_id.to_s }
    end

    def show
      authorize_admin!(@category, :show?)
      redirect_to edit_admin_category_path(@category)
    end

    def new
      authorize_admin!(Category, :new?)

      @category = Category.new(active: true, position: next_position)
      @inherited_filters = []
      @assigned_filter_ids = []
    end

    def create
      authorize_admin!(Category, :create?)

      @category = Category.new(category_params)
      if @category.save
        assign_filters
        audit!("category.created", @category)
        redirect_to edit_admin_category_path(@category), notice: t("admin.categories.created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize_admin!(@category, :edit?)

      @inherited_filters = @category.ancestors.flat_map(&:effective_filters).uniq(&:id)
      @assigned_filter_ids = @category.category_filters.order(:position, :id).pluck(:filter_definition_id)
    end

    def update
      authorize_admin!(@category, :update?)

      if @category.update(category_params)
        assign_filters
        audit!("category.updated", @category)
        redirect_to edit_admin_category_path(@category), notice: t("admin.categories.updated")
      else
        @inherited_filters = @category.ancestors.flat_map(&:effective_filters).uniq(&:id)
        @assigned_filter_ids = @category.category_filters.order(:position, :id).pluck(:filter_definition_id)
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize_admin!(@category, :destroy?)

      if @category.listings_for_delete?
        redirect_to admin_categories_path,
                    alert: t("admin.categories.delete_blocked",
                             listings: @category.listings.count, children: @category.children.count)
      else
        @category.destroy!
        audit!("category.deleted", @category, changeset: { "slug" => @category.slug })
        redirect_to admin_categories_path, notice: t("admin.categories.deleted")
      end
    end

    private

    def set_category
      @category = Category.find_by(id: params[:id]) || Category.friendly.find(params[:id])
    end

    def category_params
      permitted = params.require(:category).permit(
        :slug, :parent_id, :icon, :active, :show_in_menu, :menu_group, :position,
        names: I18n.available_locales.map(&:to_s),
        seo_descriptions: I18n.available_locales.map(&:to_s)
      )
      permitted[:names] = (permitted[:names] || {}).to_h.compact_blank
      permitted[:seo_descriptions] = (permitted[:seo_descriptions] || {}).to_h.compact_blank
      permitted
    end

    def assign_filters
      ids = params.dig(:category, :filter_definition_ids)
      return unless ids

      positions = params.dig(:category, :filter_positions) || {}
      ordered = Array(ids).map(&:to_i).reject(&:zero?)
                         .sort_by { |id| [ positions[id.to_s].to_i, Array(ids).index(id.to_s) || 0 ] }
      Admin::CategoryFilterAssigner.new(@category, ordered).call
    end

    def next_position
      Category.where(ancestry: nil).maximum(:position).to_i + 1
    end
  end
end
