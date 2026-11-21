module Seller
  class ListingsController < ApplicationController
    before_action :authenticate_user!

    def index
      @status = params[:status].to_s
      @status = "all" unless Listing.statuses.key?(@status)
      @query = params[:q].to_s.strip.first(100)
      @counts = current_user.listings.group(:status).count
      @listings = Listing.seller_board(current_user, status: @status, query: @query)
    end
  end
end
