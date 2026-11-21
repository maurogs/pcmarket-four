class CreateCountriesAndRegions < ActiveRecord::Migration[8.1]
  def change
    create_table :countries do |t|
      t.string :code, null: false
      t.string :name_key, null: false
      t.boolean :enabled, null: false, default: false
      t.string :currency, null: false, default: "EUR"
      t.decimal :vat_rate, precision: 5, scale: 2
      t.string :default_locale, null: false, default: "es"
      t.timestamps
    end
    add_index :countries, :code, unique: true
    add_index :countries, :enabled

    create_table :regions do |t|
      t.string :country_code, null: false
      t.string :name, null: false
      t.string :code
      t.timestamps
    end
    add_index :regions, :country_code
    add_index :regions, [ :country_code, :name ], unique: true
    add_foreign_key :regions, :countries, column: :country_code, primary_key: :code
  end
end
