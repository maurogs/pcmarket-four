class AccountController < ApplicationController
  layout "account"

  before_action :authenticate_user!

  def show
    load_account_summary
  end

  def update
    @user = current_user

    if @user.update(account_params)
      if @user.unconfirmed_email.present? && @user.unconfirmed_email != @user.email
        redirect_to account_path(locale: @user.locale),
                    notice: t("account.profile.email_confirmation_sent")
      else
        redirect_to account_path(locale: @user.locale), notice: t("account.profile.saved")
      end
    else
      load_account_summary
      render :show, status: :unprocessable_entity
    end
  end

  private

  def load_account_summary
    @user = current_user
    @saved_searches = current_user.saved_searches.includes(:category).order(created_at: :desc)
    @favorites_count = current_user.favorites.count
    @orders_count = current_user.orders_as_buyer.count
  end

  def account_params
    params.require(:user).permit(
      :first_name, :last_name, :username, :phone, :email, :locale, :avatar
    )
  end
end
