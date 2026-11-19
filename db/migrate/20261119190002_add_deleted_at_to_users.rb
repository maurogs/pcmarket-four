class AddDeletedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    # GDPR account deletion marker (Accounts::Deleter). The row is anonymized,
    # never removed, so reviews keep their author FK.
    add_column :users, :deleted_at, :datetime
    add_index :users, :deleted_at
  end
end
