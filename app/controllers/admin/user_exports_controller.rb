module Admin
  class UserExportsController < BaseController
    def create
      authorize_admin!(:user, :export?)

      export = Admin::UserExport.new(filter_params)
      send_data export.to_csv, filename: export.filename, type: "text/csv; charset=utf-8"
    end

    private

    def filter_params
      params.permit(:q, :role, :status, :confirmed, :has_store, :country,
                    :signed_up_from, :signed_up_to, :sort, :direction)
    end
  end
end
