# GDPR account deletion: /:locale/account/deletion. Deliberately not Devise's
# registration#destroy — that would delete the row and orphan published
# reviews. Accounts::Deleter anonymizes in place after a confirmation
# challenge: the current password, or the username for omniauth-only accounts
# (they have no usable password to type).
module Account
  class DeletionsController < ApplicationController
    before_action :authenticate_user!

    def show; end

    def destroy
      unless confirmation_valid?
        flash.now[:alert] = t(".invalid_confirmation")
        render :show, status: :unprocessable_entity
        return
      end

      user = current_user
      Accounts::Deleter.call(user)
      sign_out(user)
      redirect_to root_path, notice: t(".success")
    end

    private

    def confirmation_valid?
      confirmation = params.expect(user: :confirmation)[:confirmation].to_s
      return false if confirmation.blank?

      if current_user.omniauth_only?
        ActiveSupport::SecurityUtils.secure_compare(confirmation, current_user.username.to_s)
      else
        current_user.valid_password?(confirmation)
      end
    end
  end
end
