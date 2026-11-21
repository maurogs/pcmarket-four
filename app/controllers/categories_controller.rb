class CategoriesController < ApplicationController
  include SearchRendering

  before_action :set_category

  def show
    @search = ListingSearch.new(params: search_params, category: @category)
    render_search
    return if performed? || turbo_frame_request?

    render "listings/index"
  end

  private

  def set_category
    @category = Category.find_by_path_slugs(params[:path].to_s.split("/"))
    raise ActiveRecord::RecordNotFound if @category.nil?
  end
end
