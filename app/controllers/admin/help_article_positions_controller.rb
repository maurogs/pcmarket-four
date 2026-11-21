module Admin
  class HelpArticlePositionsController < BaseController
    def update
      authorize_admin!(HelpArticle, :update?)

      ids = Array(params[:ordered_ids]).flat_map { |value| value.to_s.split(",") }.map(&:to_i).reject(&:zero?)
      articles = HelpArticle.where(id: ids).to_a
      return head(:unprocessable_entity) unless ids.any? && articles.size == ids.size

      HelpArticle.transaction do
        ids.each_with_index do |id, index|
          HelpArticle.where(id: id).update_all(position: index, updated_at: Time.current)
        end
      end
      head :no_content
    end
  end
end
