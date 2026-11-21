class CreateStores < ActiveRecord::Migration[8.1]
  def change
    create_table :stores do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.integer :store_type, null: false, default: 0
      t.boolean :verified, null: false, default: false
      t.string :tax_id
      t.string :company_name
      t.boolean :vacation_mode, null: false, default: false
      t.text :vacation_message
      t.boolean :allow_offers_default, null: false, default: true
      t.decimal :rating_avg, precision: 3, scale: 2, null: false, default: 0
      t.integer :reviews_count, null: false, default: 0
      t.integer :followers_count, null: false, default: 0
      t.integer :sales_count, null: false, default: 0
      t.integer :listings_count, null: false, default: 0
      t.text :return_policy
      t.text :shipping_policy
      t.string :country_code
      t.references :region, foreign_key: true
      t.string :city

      t.timestamps
    end

    add_index :stores, :slug, unique: true
    add_index :stores, :country_code
    add_index :stores, :verified
  end
end
