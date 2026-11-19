class SearchesController < ApplicationController
  def show
    @query = params[:q].to_s.strip
  end
end
