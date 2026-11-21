module Admin
  class FilterOptionMergesController < BaseController
    def create
      authorize_admin!(FilterOption, :update?)

      filter = FilterDefinition.find(params[:filter_definition_id])
      merger = Admin::FilterOptionMerger.new(
        filter,
        source: params[:source_value],
        target: params[:target_value]
      )
      if merger.call
        audit!("filter_options.merged", filter,
               changeset: { "source" => params[:source_value], "target" => params[:target_value] })
        redirect_to edit_admin_filter_definition_path(filter), notice: t("admin.filters.options.merged")
      else
        redirect_to edit_admin_filter_definition_path(filter), alert: t("admin.filters.options.merge_failed")
      end
    end
  end
end
