module Admin
  class FilterOptionPositionsController < BaseController
    def update
      authorize_admin!(FilterOption, :update?)

      filter = FilterDefinition.find(params[:filter_definition_id])
      ids = Array(params[:ordered_ids]).flat_map { |value| value.to_s.split(",") }.map(&:to_i).reject(&:zero?)
      options = filter.filter_options.where(id: ids).to_a
      return head(:unprocessable_entity) unless options.size == ids.size && ids.any?

      FilterOption.transaction do
        ids.each_with_index do |id, index|
          FilterOption.where(id: id).update_all(position: index, updated_at: Time.current)
        end
      end
      ListingSearch.bust_caches!
      head :no_content
    end
  end
end
