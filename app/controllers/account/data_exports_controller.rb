module Account
  class DataExportsController < BaseController
    def create
      payload = UserDataExport.new(current_user).as_json
      send_data JSON.pretty_generate(payload),
                filename: "pcm-market-data-#{current_user.id}.json",
                type: "application/json",
                disposition: "attachment"
    end
  end
end
