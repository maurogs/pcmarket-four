class CreateProductLabels < ActiveRecord::Migration[8.1]
  def change
    create_table :product_labels do |t|
      t.string :slug, null: false
      t.jsonb :name_translations, null: false, default: {}
      # CSS color token (hex) for the badge, e.g. "#16a34a".
      t.string :color
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :product_labels, :slug, unique: true
    add_index :product_labels, [ :active, :position ]
  end
end
