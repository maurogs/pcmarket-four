# GET /search?q=… — full-text browse over published listings. Without a
# query it renders the empty search form.
class SearchesController < ApplicationController
  include Browseable

  def show
    @query = params[:q].to_s.strip
    run_search if @query.present?
  end
end
