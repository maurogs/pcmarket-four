module Users
  class TermsAcceptancesController < ApplicationController
    before_action :authenticate_user!

    def new
    end

    def create
      unless truthy?(params[:terms_accepted])
        redirect_to new_terms_acceptance_path,
                    alert: t("auth.terms_acceptance.required")
        return
      end

      current_user.update!(
        terms_accepted_at: Time.current,
        accepts_marketing: truthy?(params[:accepts_marketing])
      )

      redirect_to root_path, notice: t("auth.terms_acceptance.accepted")
    end

    private

    def truthy?(value)
      ActiveModel::Type::Boolean.new.cast(value) == true
    end
  end
end
