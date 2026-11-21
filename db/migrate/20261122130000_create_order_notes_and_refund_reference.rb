class CreateOrderNotesAndRefundReference < ActiveRecord::Migration[8.1]
  def change
    create_table :order_notes do |t|
      t.references :order, null: false, foreign_key: true
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.text :body, null: false
      t.timestamps
    end
    add_index :order_notes, [ :order_id, :created_at ]

    add_column :orders, :refund_reference, :string
    add_column :reviews, :seller_reply_visible, :boolean, default: true, null: false
  end
end
