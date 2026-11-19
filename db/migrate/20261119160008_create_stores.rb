class CreateStores < ActiveRecord::Migration[8.1]
  def change
    create_table :stores do |t|
      t.references :user, null: false, index: { unique: true }, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      # ActiveStorage `logo` and `banner` attachments are declared on the model.
      t.text :bio
      t.boolean :verified, null: false, default: false
      t.datetime :verified_at
      # 0 individual, 1 business
      t.integer :kind, null: false, default: 0
      t.string :business_name
      t.string :tax_id
      t.boolean :vacation_mode, null: false, default: false
      t.text :vacation_message
      t.boolean :allow_offers_default, null: false, default: true
      t.decimal :rating_avg, precision: 4, scale: 2, null: false, default: 0.0
      t.integer :ratings_count, null: false, default: 0
      t.integer :sales_count, null: false, default: 0
      t.integer :followers_count, null: false, default: 0
      # Published listings counter, maintained by Stores::RefreshCounters.
      t.integer :active_listings_count, null: false, default: 0
      t.references :country, foreign_key: true
      t.string :city
      t.string :province
      t.string :postal_code

      t.timestamps
    end

    add_index :stores, :slug, unique: true
    add_index :stores, [ :verified, :rating_avg ]
  end
end
