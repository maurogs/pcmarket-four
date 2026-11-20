class CreateOrderItems < ActiveRecord::Migration[8.1]
  def change
    create_table :order_items do |t|
      t.references :order, null: false, foreign_key: true
      # Historical orders must survive listing deletion, so the FK nullifies
      # instead of cascading (the snapshots below keep the row readable).
      t.references :listing, foreign_key: { on_delete: :nullify }
      t.string :title, null: false
      t.integer :unit_price_cents, null: false
      t.integer :quantity, null: false, default: 1
      t.integer :line_total_cents, null: false
      # Snapshots of the listing at purchase time.
      t.string :condition
      t.string :image_blob_signed_id
      # True when placement marked the listing sold (stock hit zero): only
      # then may cancel/refund relist it, and the unit is not re-added to
      # stock (mark_sold never decremented the quantity).
      t.boolean :sold_listing, null: false, default: false

      t.timestamps
    end

    add_check_constraint :order_items, "quantity > 0", name: "chk_order_items_quantity_positive"
    add_check_constraint :order_items, "unit_price_cents >= 0",
      name: "chk_order_items_unit_price_non_negative"
    add_check_constraint :order_items, "line_total_cents >= 0",
      name: "chk_order_items_line_total_non_negative"
  end
end
