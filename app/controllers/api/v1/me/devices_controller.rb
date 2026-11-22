module Api
  module V1
    module Me
      class DevicesController < BaseController
        before_action :authenticate!

        def create
          unless Device::PLATFORMS.include?(params[:platform].to_s)
            return render_error("validation_failed", t("api.errors.device_platform"),
                                status: :unprocessable_entity)
          end

          device = current_user.devices.find_or_initialize_by(token: params[:token])
          device.platform = params[:platform]
          device.app_version = params[:app_version]
          device.save!

          @device = device
          render "api/v1/devices/show", formats: :json, status: :created
        end

        def destroy
          current_user.devices.find(params[:id]).destroy!
          head :no_content
        end
      end
    end
  end
end
