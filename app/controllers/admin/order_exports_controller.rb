module Admin
  class OrderExportsController < BaseController
    def create
      authorize_admin!(Order, :export?)

      export = Admin::OrderExport.new(export_params)
      send_data export.to_csv,
                filename: export.filename,
                type: "text/csv",
                disposition: "attachment"
    end

    private

    def export_params
      params.permit(:status, :fulfilment, :payment_method, :seller, :buyer_email,
                    :created_from, :created_to, :min_total, :max_total,
                    :late_shipment, :refund_needed, :sort, :direction).to_h
    end
  end
end
