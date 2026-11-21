module Admin
  class CategoryPositionsController < BaseController
    def update
      authorize_admin!(Category, :update?)

      parent_id = params[:parent_id].presence
      ordered = Array(params[:ordered_ids]).flat_map { |value| value.to_s.split(",") }
      if Admin::CategoryPositioner.new(parent_id: parent_id, ordered_ids: ordered).call
        audit!("category.reordered", Category.find_by(id: ordered.first) || Category.first,
               changeset: { "ordered_ids" => ordered })
        head :no_content
      else
        head :unprocessable_entity
      end
    end
  end
end
