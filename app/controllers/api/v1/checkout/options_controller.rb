module Api
  module V1
    module Checkout
      class OptionsController < BaseController
        before_action :authenticate!

        def show
          @summary = CartSummary.for(user: current_user)
          @availability = Payments::Availability.new(@summary)
          @checkout_token = SecureRandom.uuid
          render :show, formats: :json
        end
      end
    end
  end
end
