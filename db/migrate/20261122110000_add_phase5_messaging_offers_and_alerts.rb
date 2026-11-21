class AddPhase5MessagingOffersAndAlerts < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :flagged, :boolean, default: false, null: false
    add_column :messages, :offer_expires_at, :datetime

    add_column :conversations, :buyer_archived_at, :datetime
    add_column :conversations, :seller_archived_at, :datetime

    add_column :cart_items, :offer_price_cents, :integer
    add_column :cart_items, :offer_expires_at, :datetime

    add_column :saved_searches, :frequency, :integer, default: 0, null: false

    add_index :messages, [ :conversation_id, :kind, :offer_status ],
              name: "index_messages_on_conversation_kind_and_offer_status"
  end
end
