# Account profile settings: /:locale/account/profile/edit. Email changes go
# through Devise's confirmable reconfirmation (update_without_password keeps
# the old address working until the new one is confirmed).
module Account
  class ProfilesController < ApplicationController
    before_action :authenticate_user!

    def edit; end

    def update
      if current_user.update_without_password(profile_params)
        redirect_to edit_account_profile_path, notice: t(".success")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def profile_params
      fields = %i[first_name last_name username phone locale avatar]
      fields << :email unless current_user.omniauth_only?
      params.expect(user: fields)
    end
  end
end
