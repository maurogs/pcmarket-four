class AddDataExportGeneratedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    # When the GDPR data export (User#data_export attachment) was last built;
    # also the clock behind the once-per-24h request throttle.
    add_column :users, :data_export_generated_at, :datetime
  end
end
