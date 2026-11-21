class StoresController < ApplicationController
  def show
    @store = Store.friendly.find(params[:id])
  end
end
