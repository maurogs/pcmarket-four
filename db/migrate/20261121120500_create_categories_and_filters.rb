class CreateCategoriesAndFilters < ActiveRecord::Migration[8.1]
  def change
    create_table :categories do |t|
      t.jsonb :names, null: false, default: {}
      t.string :slug, null: false
      t.string :ancestry
      t.integer :position, null: false, default: 0
      t.string :icon
      t.boolean :active, null: false, default: true
      t.boolean :show_in_menu, null: false, default: false
      t.string :menu_group
      t.jsonb :seo_descriptions, null: false, default: {}
      t.integer :listings_count, null: false, default: 0

      t.timestamps
    end

    add_index :categories, :slug, unique: true
    add_index :categories, :ancestry
    add_index :categories, [ :active, :position ]
    add_index :categories, :menu_group
    add_index :categories, [ :show_in_menu, :menu_group ]

    create_table :filter_definitions do |t|
      t.string :key, null: false
      t.jsonb :names, null: false, default: {}
      t.integer :input_type, null: false, default: 0
      t.string :unit
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :filter_definitions, :key, unique: true
    add_index :filter_definitions, [ :active, :position ]

    create_table :filter_options do |t|
      t.references :filter_definition, null: false, foreign_key: true
      t.string :value, null: false
      t.jsonb :labels, null: false, default: {}
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :filter_options, [ :filter_definition_id, :value ], unique: true

    create_table :category_filters do |t|
      t.references :category, null: false, foreign_key: true
      t.references :filter_definition, null: false, foreign_key: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :category_filters, [ :category_id, :filter_definition_id ], unique: true,
              name: "index_category_filters_on_category_and_definition"
  end
end
