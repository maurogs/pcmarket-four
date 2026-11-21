class CreateCommerce < ActiveRecord::Migration[8.1]
  def change
    create_table :cart_items do |t|
      t.references :user, foreign_key: true
      t.string :cart_token
      t.references :listing, null: false, foreign_key: true
      t.integer :quantity, null: false, default: 1

      t.timestamps
    end

    add_index :cart_items, [ :user_id, :listing_id ], unique: true, where: "user_id IS NOT NULL"
    add_index :cart_items, [ :cart_token, :listing_id ], unique: true, where: "cart_token IS NOT NULL"
    add_index :cart_items, :cart_token
    add_check_constraint :cart_items,
                         "(user_id IS NOT NULL) <> (cart_token IS NOT NULL)",
                         name: "cart_items_exactly_one_owner"

    create_table :addresses do |t|
      t.references :user, null: false, foreign_key: true
      t.string :full_name, null: false
      t.string :line1, null: false
      t.string :line2
      t.string :city, null: false
      t.string :postal_code, null: false
      t.references :region, foreign_key: true
      t.string :country_code, null: false
      t.string :phone
      t.boolean :default, null: false, default: false

      t.timestamps
    end

    add_index :addresses, [ :user_id, :default ]
    add_foreign_key :addresses, :countries, column: :country_code, primary_key: :code

    create_table :orders do |t|
      t.string :number, null: false
      t.references :buyer, null: false, foreign_key: { to_table: :users }
      t.references :seller, null: false, foreign_key: { to_table: :users }
      t.references :store, foreign_key: true
      t.integer :status, null: false, default: 0
      t.integer :fulfilment, null: false, default: 0
      t.integer :subtotal_cents, null: false, default: 0
      t.integer :shipping_cents, null: false, default: 0
      t.integer :commission_cents, null: false, default: 0
      t.decimal :commission_percent, precision: 5, scale: 2
      t.integer :total_cents, null: false, default: 0
      t.string :currency, null: false, default: "EUR"
      t.string :ship_name
      t.string :ship_line1
      t.string :ship_line2
      t.string :ship_city
      t.string :ship_postal_code
      t.string :ship_region
      t.string :ship_country_code
      t.string :ship_phone
      t.string :buyer_email
      t.string :tracking_number
      t.string :carrier
      t.datetime :paid_at
      t.datetime :shipped_at
      t.datetime :delivered_at
      t.datetime :completed_at
      t.datetime :cancelled_at
      t.text :cancel_reason
      t.string :payment_provider
      t.string :payment_reference
      t.text :notes

      t.timestamps
    end

    add_index :orders, :number, unique: true
    add_index :orders, :status
    add_index :orders, :fulfilment
    add_index :orders, [ :buyer_id, :created_at ]
    add_index :orders, [ :seller_id, :created_at ]
    add_index :orders, :paid_at

    create_table :order_items do |t|
      t.references :order, null: false, foreign_key: true
      t.references :listing, null: false, foreign_key: true
      t.string :title_snapshot, null: false
      t.integer :price_cents, null: false
      t.integer :quantity, null: false, default: 1

      t.timestamps
    end

    add_index :order_items, [ :order_id, :listing_id ], unique: true

    create_table :reviews do |t|
      t.references :order, null: false, foreign_key: true, index: { unique: true }
      t.references :reviewer, null: false, foreign_key: { to_table: :users }
      t.references :store, null: false, foreign_key: true
      t.integer :rating, null: false
      t.text :body
      t.text :seller_reply
      t.boolean :published, null: false, default: true

      t.timestamps
    end

    add_index :reviews, [ :store_id, :published ]
    add_index :reviews, :rating
  end
end
