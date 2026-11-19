class CreateCategoryFilters < ActiveRecord::Migration[8.1]
  def change
    create_table :category_filters do |t|
      t.references :category, null: false, foreign_key: { to_table: :categories }
      t.references :filter_definition, null: false, foreign_key: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :category_filters, [ :category_id, :filter_definition_id ], unique: true
    add_index :category_filters, [ :category_id, :position ]
  end
end
