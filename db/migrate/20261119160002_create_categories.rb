class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories do |t|
      t.references :parent, foreign_key: { to_table: :categories }
      t.string :slug, null: false
      t.integer :position, null: false, default: 0
      # { "en" => "Graphics Cards", "es" => "Tarjetas gráficas", … }
      t.jsonb :name_translations, null: false, default: {}
      t.jsonb :description_translations, null: false, default: {}
      t.jsonb :seo_title_translations, null: false, default: {}
      t.jsonb :seo_description_translations, null: false, default: {}
      t.string :icon
      # ActiveStorage `image` attachment is declared on the model.
      t.boolean :active, null: false, default: true
      # Published listings in this category *and all descendants*.
      # Maintained by Categories::RefreshListingsCount, never by hand.
      t.integer :listings_count, null: false, default: 0
      # 0 full_system, 1 component, 2 peripheral, 3 mobile,
      # 4 gaming_system, 5 accessory, 6 software
      t.integer :kind, null: false, default: 0

      t.timestamps
    end

    add_index :categories, :slug, unique: true
    add_index :categories, :kind
    add_index :categories, :active
    add_index :categories, [ :parent_id, :position ]
  end
end
