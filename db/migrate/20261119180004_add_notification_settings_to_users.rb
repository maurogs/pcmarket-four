class AddNotificationSettingsToUsers < ActiveRecord::Migration[8.1]
  def change
    # Flat jsonb map of User::NOTIFICATION_KEYS => true/false (see User#notify?).
    add_column :users, :notification_preferences, :jsonb, null: false, default: {}
    add_column :users, :marketing_opt_in, :boolean, null: false, default: false
    add_column :users, :marketing_opt_in_at, :datetime
  end
end
