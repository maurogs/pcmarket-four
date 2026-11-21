class CreateBuybackPrices < ActiveRecord::Migration[8.1]
  def change
    create_table :buyback_prices do |t|
      t.integer :item_kind, null: false, default: 0
      t.string :model_name, null: false
      t.integer :base_price_cents, null: false, default: 0
      t.jsonb :condition_multipliers, null: false, default: {}
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :buyback_prices, [ :item_kind, :model_name ], unique: true
    add_index :buyback_prices, [ :active, :item_kind, :position ]
  end
end
