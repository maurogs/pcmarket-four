class CategoriesController < ApplicationController
  before_action :set_category

  def show
  end

  private

  def set_category
    @category = Category.find_by_path_slugs(params[:path].to_s.split("/"))
    raise ActiveRecord::RecordNotFound if @category.nil?
  end
end
