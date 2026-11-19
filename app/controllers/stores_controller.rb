# GET /s/:slug — public seller storefront (tabs: Listings / About / Reviews).
class StoresController < ApplicationController
  include Browseable

  before_action :set_store

  def show
    @tab = params[:tab].to_s.presence_in(%w[listings about reviews]) || "listings"
    run_search(store: @store) if @tab == "listings"
  end

  private

  def set_store
    @store = Store.find_by_param(params[:slug])
    render_not_found unless @store
  end
end
