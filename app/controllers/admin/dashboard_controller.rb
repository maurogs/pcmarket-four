module Admin
  class DashboardController < BaseController
    def show
      authorize_admin!(:dashboard, :dashboard?)
      @dashboard = Admin::Dashboard.new.data
    end
  end
end
