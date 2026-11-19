class CreateFilterOptions < ActiveRecord::Migration[8.1]
  def change
    create_table :filter_options do |t|
      t.references :filter_definition, null: false, foreign_key: true
      # Stable machine value stored in listing specs (e.g. "samsung_990_pro").
      t.string :value, null: false
      t.jsonb :label_translations, null: false, default: {}
      t.integer :position, null: false, default: 0
      # For sorting and range filters (e.g. 16 for 16 GB, 850 for 850 W).
      t.decimal :numeric_value, precision: 12, scale: 4
      # Featured options render first; the rest hides behind "show more".
      t.boolean :featured, null: false, default: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :filter_options, [ :filter_definition_id, :value ], unique: true
    add_index :filter_options, [ :filter_definition_id, :position ]
    add_index :filter_options, :featured
  end
end
