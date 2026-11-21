module Admin
  class FilterDefinitionsController < BaseController
    before_action :set_filter, only: %i[show edit update destroy]

    def index
      authorize_admin!(FilterDefinition, :index?)

      @filters = FilterDefinition.includes(:filter_options, categories: :category_filters)
                                 .order(:position, :id)
      @usage_counts = Listing.where("specs IS NOT NULL").pluck(:specs).each_with_object(Hash.new(0)) do |specs, counts|
        specs.each_key { |key| counts[key] += 1 }
      end
    end

    def show
      authorize_admin!(@filter, :show?)
      redirect_to edit_admin_filter_definition_path(@filter)
    end

    def new
      authorize_admin!(FilterDefinition, :new?)

      @filter = FilterDefinition.new(active: true, input_type: :checkbox, position: next_position)
    end

    def create
      authorize_admin!(FilterDefinition, :create?)

      @filter = FilterDefinition.new(filter_params)
      if @filter.save
        assign_categories
        audit!("filter.created", @filter)
        redirect_to edit_admin_filter_definition_path(@filter), notice: t("admin.filters.created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize_admin!(@filter, :edit?)

      @options = @filter.filter_options.order(:position, :id)
      @usage_counts = option_usage_counts
    end

    def update
      authorize_admin!(@filter, :update?)

      if @filter.update(filter_params)
        assign_categories
        audit!("filter.updated", @filter)
        redirect_to edit_admin_filter_definition_path(@filter), notice: t("admin.filters.updated")
      else
        @options = @filter.filter_options.order(:position, :id)
        @usage_counts = option_usage_counts
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize_admin!(@filter, :destroy?)

      unless params[:confirm_key].to_s == @filter.key
        redirect_to edit_admin_filter_definition_path(@filter),
                    alert: t("admin.filters.confirm_key_mismatch")
        return
      end

      key = @filter.key
      if @filter.listing_usage_count.positive?
        CleanupSpecKeyJob.perform_later(key)
      end
      @filter.destroy!
      audit!("filter.deleted", @filter, changeset: { "key" => key })
      redirect_to admin_filter_definitions_path, notice: t("admin.filters.deleted")
    end

    private

    def set_filter
      @filter = FilterDefinition.find(params[:id])
    end

    def filter_params
      permitted = params.require(:filter_definition).permit(
        :key, :input_type, :unit, :position, :active,
        names: I18n.available_locales.map(&:to_s)
      )
      permitted[:names] = (permitted[:names] || {}).to_h.compact_blank
      permitted
    end

    def assign_categories
      ids = params.dig(:filter_definition, :category_ids)
      return unless ids

      ids = Array(ids).map(&:to_i).reject(&:zero?)
      FilterDefinition.transaction do
        @filter.category_filters.where.not(category_id: ids).destroy_all
        ids.each { |category_id| @filter.category_filters.find_or_create_by!(category_id: category_id) }
      end
    end

    def option_usage_counts
      key = @filter.key
      Listing.where("specs ? :key", key: key).pluck(Arel.sql("specs ->> '#{key}'"))
             .each_with_object(Hash.new(0)) { |value, counts| counts[value] += 1 }
    end

    def next_position
      FilterDefinition.maximum(:position).to_i + 1
    end
  end
end
