class CreateSavedSearchesAndMessaging < ActiveRecord::Migration[8.1]
  def change
    create_table :saved_searches do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :query
      t.references :category, foreign_key: true
      t.jsonb :filters, null: false, default: {}
      t.integer :min_price_cents
      t.integer :max_price_cents
      t.string :country_code
      t.boolean :notify, null: false, default: true
      t.datetime :last_notified_at

      t.timestamps
    end

    add_index :saved_searches, :country_code
    add_index :saved_searches, [ :user_id, :notify ]

    create_table :conversations do |t|
      t.references :listing, foreign_key: true
      t.references :buyer, null: false, foreign_key: { to_table: :users }
      t.references :seller, null: false, foreign_key: { to_table: :users }
      t.datetime :last_message_at
      t.integer :buyer_unread_count, null: false, default: 0
      t.integer :seller_unread_count, null: false, default: 0

      t.timestamps
    end

    add_index :conversations, [ :listing_id, :buyer_id, :seller_id ], unique: true,
              name: "index_conversations_on_listing_and_participants"
    add_index :conversations, [ :buyer_id, :last_message_at ]
    add_index :conversations, [ :seller_id, :last_message_at ]

    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :sender, null: false, foreign_key: { to_table: :users }
      t.text :body, null: false
      t.integer :kind, null: false, default: 0
      t.integer :offer_amount_cents
      t.integer :offer_status
      t.datetime :read_at

      t.timestamps
    end

    add_index :messages, [ :conversation_id, :created_at ]
    add_index :messages, :read_at

    create_table :blocks do |t|
      t.references :blocker, null: false, foreign_key: { to_table: :users }
      t.references :blocked, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :blocks, [ :blocker_id, :blocked_id ], unique: true
  end
end
