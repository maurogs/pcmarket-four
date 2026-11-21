class CreateOrderEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :order_events do |t|
      t.references :order, null: false, foreign_key: true
      t.references :actor, foreign_key: { to_table: :users }
      t.string :kind, null: false
      t.jsonb :data, null: false, default: {}
      t.datetime :created_at, null: false
    end

    add_index :order_events, [ :order_id, :created_at ]

    add_column :orders, :disputed_at, :datetime
    add_column :orders, :refunded_at, :datetime
    add_column :orders, :refund_required, :boolean, null: false, default: false
    add_column :orders, :late_shipment_notified_at, :datetime
    add_index :orders, :disputed_at
  end
end
