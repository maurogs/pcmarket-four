module Admin
  class DashboardController < ApplicationController
    before_action :require_staff

    def show
    end
  end
end
