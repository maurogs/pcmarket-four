class CreateCartItems < ActiveRecord::Migration[8.1]
  def change
    create_table :cart_items do |t|
      # The unique [cart_id, listing_id] index below doubles as the cart_id
      # FK index; listing_id keeps its plain index for reverse lookups.
      t.references :cart, null: false, foreign_key: true, index: false
      t.references :listing, null: false, foreign_key: true
      t.integer :quantity, null: false, default: 1
      # Price snapshot at add time; Cart#refresh! syncs it with the listing.
      t.integer :unit_price_cents, null: false

      t.timestamps
    end

    add_index :cart_items, [ :cart_id, :listing_id ], unique: true
    add_check_constraint :cart_items, "quantity > 0", name: :chk_cart_items_quantity_positive
  end
end
