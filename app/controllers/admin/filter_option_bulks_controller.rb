module Admin
  class FilterOptionBulksController < BaseController
    def create
      authorize_admin!(FilterOption, :create?)

      filter = FilterDefinition.find(params[:filter_definition_id])
      values = params[:values].to_s.split(/\r?\n/).map(&:strip).reject(&:blank?).uniq
      created = 0
      filter.filter_options.transaction do
        values.each_with_index do |value, index|
          option = filter.filter_options.find_or_initialize_by(value: value)
          next if option.persisted?

          option.position = filter.filter_options.maximum(:position).to_i + index + 1
          option.labels = I18n.available_locales.index_with { value }
          created += 1 if option.save
        end
      end
      audit!("filter_options.bulk_created", filter, changeset: { "count" => created })
      redirect_to edit_admin_filter_definition_path(filter),
                  notice: t("admin.filters.options.bulk_created", count: created)
    end
  end
end
