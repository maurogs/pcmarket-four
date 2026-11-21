module Seller
  class PayoutsController < BaseController
    def show
      @store = seller_store
    end
  end
end
