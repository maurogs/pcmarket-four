# GDPR data export page: /:locale/account/data_export. GET shows the current
# export (if any) plus a request button; POST enqueues Account::DataExportJob.
# The once-per-24h throttle is User#data_export_throttled? — checked here
# before enqueueing so the user gets an immediate flash instead of a job that
# does nothing.
module Account
  class DataExportsController < ApplicationController
    before_action :authenticate_user!

    def show; end

    def create
      if current_user.data_export_throttled?
        redirect_to account_data_export_path, alert: t(".throttled")
      else
        Account::DataExportJob.perform_later(current_user.id)
        redirect_to account_data_export_path, notice: t(".requested")
      end
    end
  end
end
