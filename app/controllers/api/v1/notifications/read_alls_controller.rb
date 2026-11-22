module Api
  module V1
    module Notifications
      class ReadAllsController < BaseController
        before_action :authenticate!

        def create
          @updated = current_user.notifications.unread.update_all(read_at: Time.current,
                                                                  updated_at: Time.current)

          render :create, formats: :json, status: :created
        end
      end
    end
  end
end
