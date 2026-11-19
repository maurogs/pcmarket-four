class CreateFilterDefinitions < ActiveRecord::Migration[8.1]
  def change
    create_table :filter_definitions do |t|
      t.string :key, null: false
      t.jsonb :label_translations, null: false, default: {}
      # Sidebar grouping, e.g. { "en" => "CPU", "es" => "CPU", … }
      t.jsonb :group_translations, null: false, default: {}
      # 0 multi_select, 1 single_select, 2 range, 3 boolean
      t.integer :input_type, null: false, default: 0
      t.string :unit
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.boolean :show_in_sidebar, null: false, default: true
      t.boolean :show_in_listing_form, null: false, default: true
      t.boolean :required_in_form, null: false, default: false
      t.boolean :searchable, null: false, default: true

      t.timestamps
    end

    add_index :filter_definitions, :key, unique: true
    add_index :filter_definitions, [ :active, :position ]
  end
end
