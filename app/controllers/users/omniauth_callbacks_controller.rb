class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    auth = request.env["omniauth.auth"]

    unless GoogleEmailVerification.verified_auth?(auth)
      redirect_to new_user_session_path, alert: t("errors.omniauth_email_unverified")
      return
    end

    user = User.from_omniauth(auth)

    if user&.persisted?
      sign_in user, event: :authentication
      set_flash_message(:notice, :success, kind: "Google") if is_navigational_format?

      if user.terms_accepted_at.present?
        redirect_to after_sign_in_path_for(user)
      else
        redirect_to new_terms_acceptance_path
      end
    else
      redirect_to new_user_session_path,
                  alert: t("errors.omniauth_failure")
    end
  end

  def failure
    redirect_to root_path, alert: t("errors.omniauth_failure")
  end
end
