class CreateFollows < ActiveRecord::Migration[8.1]
  def change
    create_table :follows do |t|
      # follower_id is covered by the composite unique index below.
      t.references :follower, null: false, index: false, foreign_key: { to_table: :users }
      t.references :store, null: false, foreign_key: true

      t.timestamps
    end

    add_index :follows, [ :follower_id, :store_id ], unique: true
  end
end
