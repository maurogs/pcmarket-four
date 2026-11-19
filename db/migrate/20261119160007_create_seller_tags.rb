class CreateSellerTags < ActiveRecord::Migration[8.1]
  def change
    create_table :seller_tags do |t|
      t.string :slug, null: false
      t.jsonb :name_translations, null: false, default: {}
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :seller_tags, :slug, unique: true
  end
end
