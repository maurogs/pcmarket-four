class AccountController < ApplicationController
  before_action :authenticate_user!

  def show
    @saved_searches = current_user.saved_searches.includes(:category).order(created_at: :desc)
    @favorites_count = current_user.favorites.count
    @orders_count = current_user.orders_as_buyer.count
  end
end
