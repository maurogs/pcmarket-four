module Admin
  class FeatureRequestsController < BaseController
    before_action :set_request, only: :show

    def index
      authorize_admin!(FeatureRequest, :index?)

      scope = FeatureRequest.includes(:user, :listing).recent
      scope = scope.where(status: params[:status]) if params[:status].present? && FeatureRequest.statuses.key?(params[:status])
      @pagy, @requests = pagy(scope, limit: pagination_limit)
    end

    def show
      authorize_admin!(@request, :show?)

      redirect_to admin_feature_requests_path
    end

    private

    def set_request
      @request = FeatureRequest.find(params[:id])
    end
  end
end
