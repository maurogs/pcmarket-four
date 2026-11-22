module Api
  module V1
    module Me
      class TermsAcceptancesController < BaseController
        before_action :authenticate!

        def create
          unless truthy?(params[:terms_accepted])
            return render_error("validation_failed", t("api.errors.terms_required"),
                                status: :unprocessable_entity,
                                details: { "terms_accepted" => [ t("api.errors.terms_required") ] })
          end

          current_user.update!(
            terms_accepted_at: Time.current,
            accepts_marketing: truthy?(params[:accepts_marketing])
          )

          @user = current_user
          render "api/v1/me/show", formats: :json
        end
      end
    end
  end
end
