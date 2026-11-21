module Admin
  class BaseController < ApplicationController
    include Admin::Auditable

    layout "admin"

    before_action :authenticate_user!
    before_action :require_staff

    helper_method :pending_moderation_count, :sidebar_counts

    private

    def sidebar_counts
      @sidebar_counts ||= begin
        if defined?(@dashboard) && @dashboard.present?
          {
            open_disputes: @dashboard[:stats][:open_disputes][:value],
            open_reports: @dashboard[:stats][:open_reports][:value],
            pending_payments: @dashboard[:stats][:pending_payments][:value]
          }
        else
          Admin::SidebarCounts.call
        end
      end
    end

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
