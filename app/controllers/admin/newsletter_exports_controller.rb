module Admin
  class NewsletterExportsController < BaseController
    def show
      authorize_admin!(NewsletterSubscriber, :index?)

      rows = NewsletterSubscriber.order(:created_at).map do |subscriber|
        [
          subscriber.email,
          subscriber.locale,
          subscriber.confirmed_at&.iso8601,
          subscriber.unsubscribed_at&.iso8601
        ]
      end
      csv = [ %w[email locale confirmed_at unsubscribed_at] ] + rows
      send_data csv.map { |row| row.map { |cell| "\"#{cell.to_s.gsub('"', '""')}\"" }.join(",") }.join("\n"),
                filename: "newsletter-subscribers-#{Date.current}.csv",
                type: "text/csv"
    end
  end
end
