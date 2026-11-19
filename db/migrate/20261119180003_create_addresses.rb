class CreateAddresses < ActiveRecord::Migration[8.1]
  def change
    create_table :addresses do |t|
      t.references :user, null: false, foreign_key: true
      t.string :label
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :company
      t.string :street_line1, null: false
      t.string :street_line2
      t.string :city, null: false
      # SpanishProvince code (INE two-digit); only used for ES addresses.
      t.string :province
      t.string :postal_code, null: false
      t.references :country, null: false, foreign_key: true
      t.string :phone
      t.boolean :default_shipping, null: false, default: false

      t.timestamps
    end

    # At most one default shipping address per user. (Distinct name from the
    # plain user_id FK index that t.references creates.)
    add_index :addresses, :user_id, unique: true, where: "(default_shipping)",
              name: :index_addresses_on_user_id_unique_default
  end
end
