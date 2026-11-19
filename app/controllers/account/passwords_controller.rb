# Password change: /:locale/account/password/edit. update_with_password
# verifies current_password; bypass_sign_in keeps the session alive after the
# rotation (Devise would otherwise sign the user out).
module Account
  class PasswordsController < ApplicationController
    before_action :authenticate_user!

    def edit; end

    def update
      if current_user.update_with_password(password_params)
        bypass_sign_in(current_user, scope: :user)
        redirect_to edit_account_password_path, notice: t(".success")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def password_params
      params.expect(user: %i[current_password password password_confirmation])
    end
  end
end
