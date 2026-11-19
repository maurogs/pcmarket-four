# GET /c/:slug — browse one category (with all its descendants).
class CategoriesController < ApplicationController
  include Browseable

  before_action :set_category

  def show
    run_search(category: @category)
  end

  private

  def set_category
    @category = Category.active.find_by_param(params[:slug])
    render_not_found unless @category
  end
end
