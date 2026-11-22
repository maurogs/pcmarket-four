module Api
  module V1
    module Auth
      class PasswordsController < BaseController
        def create
          user = User.find_by(email: params[:email].to_s.strip.downcase)
          user&.send_reset_password_instructions

          render :create, formats: :json, status: :accepted
        end
      end
    end
  end
end
