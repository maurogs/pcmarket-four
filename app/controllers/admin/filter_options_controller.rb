module Admin
  class FilterOptionsController < BaseController
    before_action :set_filter

    def create
      authorize_admin!(FilterOption, :create?)

      @option = @filter.filter_options.new(option_params)
      if @option.save
        audit!("filter_option.created", @filter, changeset: { "value" => @option.value })
        redirect_to edit_admin_filter_definition_path(@filter), notice: t("admin.filters.options.created")
      else
        redirect_to edit_admin_filter_definition_path(@filter), alert: t("admin.filters.options.invalid")
      end
    end

    def update
      authorize_admin!(FilterOption, :update?)

      @option = @filter.filter_options.find(params[:id])
      if @option.update(option_params)
        audit!("filter_option.updated", @filter, changeset: { "value" => @option.value })
        redirect_to edit_admin_filter_definition_path(@filter), notice: t("admin.filters.options.updated")
      else
        redirect_to edit_admin_filter_definition_path(@filter), alert: t("admin.filters.options.invalid")
      end
    end

    def destroy
      authorize_admin!(FilterOption, :destroy?)

      option = @filter.filter_options.find(params[:id])
      value = option.value
      option.destroy!
      audit!("filter_option.deleted", @filter, changeset: { "value" => value })
      redirect_to edit_admin_filter_definition_path(@filter), notice: t("admin.filters.options.deleted")
    end

    private

    def set_filter
      @filter = FilterDefinition.find(params[:filter_definition_id])
    end

    def option_params
      permitted = params.require(:filter_option).permit(
        :value, :position,
        labels: I18n.available_locales.map(&:to_s)
      )
      permitted[:labels] = (permitted[:labels] || {}).to_h.compact_blank
      permitted
    end
  end
end
