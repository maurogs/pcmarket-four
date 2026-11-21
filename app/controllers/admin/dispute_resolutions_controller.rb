module Admin
  class DisputeResolutionsController < BaseController
    def create
      order = Order.find_by!(number: params[:dispute_id])
      outcome = params[:outcome].to_s
      authorize_admin!(order, outcome == "refund" ? :refund? : :release?)

      resolution = Admin::DisputeResolution.new(current_user, order,
                                                outcome: outcome,
                                                message: params[:message])
      if resolution.call
        audit!("order.dispute_resolved", order,
               changeset: { "status" => [ "disputed", outcome ],
                            "outcome" => outcome, "message" => params[:message].to_s })
        redirect_to admin_disputes_path, notice: t("admin.disputes.resolved")
      else
        redirect_to admin_dispute_path(order), alert: t("admin.disputes.cannot_resolve")
      end
    end
  end
end
