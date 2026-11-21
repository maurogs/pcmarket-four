module Admin
  # Filtered user export. CSV is generated manually because Ruby 4 removed the
  # csv library from the default gems.
  class UserExport
    HEADERS = %w[id email username first_name last_name role status country_code
                 confirmed_at created_at last_sign_in_at sign_in_count listings_count store_name].freeze

    def initialize(params = {})
      @params = params
    end

    def to_csv
      lines = [ HEADERS.join(",") ]
      Admin::UserQuery.new(@params).call.find_each do |user|
        lines << row(user).map { |value| quote(value) }.join(",")
      end
      lines.join("\n") + "\n"
    end

    def filename
      "pcmarket-users-#{Date.current.iso8601}.csv"
    end

    private

    def row(user)
      [
        user.id,
        user.email,
        user.username,
        user.first_name,
        user.last_name,
        user.role,
        user.status,
        user.country_code,
        user.confirmed_at&.iso8601,
        user.created_at.iso8601,
        user.last_sign_in_at&.iso8601,
        user.sign_in_count,
        user.listings.count,
        user.store&.name
      ]
    end

    def quote(value)
      %("#{value.to_s.gsub('"', '""')}")
    end
  end
end
