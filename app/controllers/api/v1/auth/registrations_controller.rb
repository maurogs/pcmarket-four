module Api
  module V1
    module Auth
      class RegistrationsController < BaseController
        def create
          unless Setting.enabled?("registrations_enabled")
            return render_error("registrations_disabled", t("api.errors.registrations_disabled"),
                                status: :forbidden)
          end

          user = User.new(
            email: params[:email],
            password: params[:password],
            password_confirmation: params[:password_confirmation] || params[:password],
            first_name: params[:first_name],
            last_name: params[:last_name],
            phone: params[:phone],
            country_code: params[:country_code].presence || "ES",
            locale: requested_locale,
            accepts_marketing: truthy?(params[:accepts_marketing])
          )
          user.terms_required = true
          user.terms_accepted = params[:terms_accepted]

          unless user.save
            details = user.errors.to_hash.transform_values { |messages| Array(messages) }
            return render_error("validation_failed", t("api.errors.validation_failed"),
                                status: :unprocessable_entity, details: details)
          end

          @user = user
          render :create, formats: :json, status: :created
        end
      end
    end
  end
end
