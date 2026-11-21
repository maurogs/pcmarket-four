module Admin
  class GamePositionsController < BaseController
    def update
      authorize_admin!(Game, :update?)

      ids = Array(params[:ordered_ids]).flat_map { |value| value.to_s.split(",") }.map(&:to_i).reject(&:zero?)
      games = Game.where(id: ids).to_a
      return head(:unprocessable_entity) unless ids.any? && games.size == ids.size

      Game.transaction do
        ids.each_with_index do |id, index|
          Game.where(id: id).update_all(position: index, updated_at: Time.current)
        end
      end
      head :no_content
    end
  end
end
