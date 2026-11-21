class CreateListings < ActiveRecord::Migration[8.1]
  def change
    create_table :listings do |t|
      t.references :user, null: false, foreign_key: true
      t.references :store, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.string :title, null: false
      t.string :slug, null: false
      t.text :description, null: false
      t.integer :price_cents, null: false, default: 0
      t.integer :original_price_cents
      t.string :currency, null: false, default: "EUR"
      t.integer :condition, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.text :rejection_reason
      t.datetime :published_at
      t.datetime :reviewed_at
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.integer :quantity, null: false, default: 1
      t.jsonb :specs, null: false, default: {}
      t.string :brand
      t.string :model_name_text
      t.string :country_code, null: false, default: "ES"
      t.references :region, foreign_key: true
      t.string :city
      t.string :postal_code
      t.boolean :shipping_available, null: false, default: true
      t.boolean :local_pickup, null: false, default: false
      t.integer :shipping_price_cents, null: false, default: 0
      t.boolean :free_shipping, null: false, default: false
      t.integer :ships_within_days, null: false, default: 3
      t.boolean :accepts_offers, null: false, default: false
      t.datetime :featured_until
      t.integer :views_count, null: false, default: 0
      t.integer :favorites_count, null: false, default: 0
      t.string :labels, array: true, null: false, default: []
      t.string :tags, array: true, null: false, default: []
      t.integer :performance_score
      t.jsonb :game_fps, null: false, default: {}

      t.timestamps
    end

    add_index :listings, :slug, unique: true
    add_index :listings, :status
    add_index :listings, :condition
    add_index :listings, :country_code
    add_index :listings, :price_cents
    add_index :listings, :published_at
    add_index :listings, :featured_until
    add_index :listings, :brand
    add_index :listings, [ :category_id, :status ]
    add_index :listings, [ :status, :published_at ]
    add_index :listings, [ :country_code, :status ]
    add_index :listings, :specs, using: :gin
    add_index :listings, :labels, using: :gin
    add_index :listings, :tags, using: :gin
    add_index :listings, :title, using: :gin, opclass: :gin_trgm_ops
    add_index :listings, :description, using: :gin, opclass: :gin_trgm_ops

    add_foreign_key :listings, :countries, column: :country_code, primary_key: :code

    create_table :favorites do |t|
      t.references :user, null: false, foreign_key: true
      t.references :listing, null: false, foreign_key: true

      t.timestamps
    end

    add_index :favorites, [ :user_id, :listing_id ], unique: true

    create_table :follows do |t|
      t.references :follower, null: false, foreign_key: { to_table: :users }
      t.references :store, null: false, foreign_key: true

      t.timestamps
    end

    add_index :follows, [ :follower_id, :store_id ], unique: true
  end
end
