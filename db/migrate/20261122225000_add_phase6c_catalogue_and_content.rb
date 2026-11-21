class AddPhase6cCatalogueAndContent < ActiveRecord::Migration[8.1]
  def change
    create_table :feature_requests do |t|
      t.references :listing, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :days, null: false, default: 7
      t.integer :price_cents, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.datetime :paid_at
      t.timestamps
    end
    add_index :feature_requests, %i[status created_at]
    add_index :feature_requests, %i[listing_id status]

    create_table :help_articles do |t|
      t.string :slug, null: false
      t.integer :category, null: false, default: 0
      t.jsonb :titles, null: false, default: {}
      t.jsonb :bodies, null: false, default: {}
      t.integer :position, null: false, default: 0
      t.boolean :published, null: false, default: true
      t.timestamps
    end
    add_index :help_articles, :slug, unique: true
    add_index :help_articles, %i[published category position]

    add_column :legal_pages, :published_at, :datetime
    add_column :settings, :feature_flag, :boolean, null: false, default: false
  end
end
