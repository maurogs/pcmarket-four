module Admin
  class UserConfirmationsController < BaseController
    def create
      user = User.find(params[:user_id])
      authorize_admin!(user, :confirm_email?)

      user.update!(confirmed_at: user.confirmed_at || Time.current,
                    confirmation_token: nil, unconfirmed_email: nil)
      audit!("user.confirmed", user, changeset: { "confirmed_at" => [ nil, user.confirmed_at ] })
      redirect_back_or_to admin_user_path(user), notice: t("admin.users.confirmed")
    end
  end
end
