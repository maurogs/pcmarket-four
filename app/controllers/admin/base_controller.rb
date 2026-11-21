module Admin
  class BaseController < ApplicationController
    include Admin::Auditable

    layout "admin"

    before_action :authenticate_user!
    before_action :require_staff

    helper_method :pending_moderation_count

    private

    def require_staff
      return if current_user&.staff?

      redirect_to root_path, alert: t("errors.not_authorized")
    end

    def pending_moderation_count
      @pending_moderation_count ||= begin
        if defined?(@dashboard) && @dashboard.present?
          @dashboard[:stats][:pending_review][:value]
        else
          Rails.cache.fetch("admin/pending_moderation_count", expires_in: 30.seconds) do
            Listing.pending_review.count
          end
        end
      end
    end

    def authorize_admin!(record, query)
      authorize([ :admin, record ], query)
    end

    def pagination_limit
      limit = params[:per_page].to_i
      AdminHelper::PAGINATION_LIMITS.include?(limit) ? limit : AdminHelper::PAGINATION_LIMITS.first
    end
  end
end
