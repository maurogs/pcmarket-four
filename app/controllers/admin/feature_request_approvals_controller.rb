module Admin
  class FeatureRequestApprovalsController < BaseController
    def create
      request = FeatureRequest.find(params[:feature_request_id])
      authorize_admin!(request, :approve?)

      if request.pending?
        request.approve!
        audit!("feature_request.approved", request,
               changeset: { "listing_id" => request.listing_id, "days" => request.days })
        redirect_to admin_feature_requests_path, notice: t("admin.feature_requests.approved")
      else
        redirect_to admin_feature_requests_path, alert: t("admin.feature_requests.not_pending")
      end
    end
  end
end
