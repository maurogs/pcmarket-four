module Account
  # Builds the signed-in user's GDPR data export in the background
  # (Accounts::DataExporter). TODO Phase 6: email a download notification
  # once the mailer wiring lands.
  class DataExportJob < ApplicationJob
    queue_as :default

    def perform(user_id)
      user = User.find_by(id: user_id)
      return if user.nil? || user.deleted?

      Accounts::DataExporter.call(user)
    end
  end
end
