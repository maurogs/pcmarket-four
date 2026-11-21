module Seller
  class BaseController < ApplicationController
    layout "seller"

    before_action :authenticate_user!

    helper_method :seller_store

    private

    def seller_store
      @seller_store ||= current_user.ensure_store!
    end
  end
end
