class CreateNotificationsAndAdmin < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.string :kind, null: false
      t.jsonb :params, null: false, default: {}
      t.string :url
      t.datetime :read_at

      t.timestamps
    end

    add_index :notifications, [ :user_id, :read_at ]
    add_index :notifications, :created_at

    create_table :reports do |t|
      t.references :reporter, null: false, foreign_key: { to_table: :users }
      t.references :reportable, polymorphic: true, null: false
      t.integer :reason, null: false, default: 0
      t.text :details
      t.integer :status, null: false, default: 0
      t.references :resolved_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :reports, :status
    add_index :reports, [ :reportable_type, :reportable_id ]

    create_table :legal_pages do |t|
      t.string :slug, null: false
      t.string :country_code
      t.string :locale, null: false, default: "es"
      t.string :title, null: false
      t.text :body, null: false
      t.integer :version, null: false, default: 1
      t.boolean :published, null: false, default: true
      t.references :updated_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :legal_pages, [ :slug, :country_code, :locale ], unique: true
    add_index :legal_pages, :slug
    add_index :legal_pages, [ :published, :locale ]

    create_table :admin_audit_logs do |t|
      t.references :admin, null: false, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.references :auditable, polymorphic: true
      t.jsonb :changeset, null: false, default: {}
      t.string :ip

      t.timestamps
    end

    add_index :admin_audit_logs, :action
    add_index :admin_audit_logs, :created_at

    create_table :api_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token, null: false
      t.string :name
      t.datetime :last_used_at
      t.datetime :expires_at

      t.timestamps
    end

    add_index :api_tokens, :token, unique: true
    add_index :api_tokens, :expires_at
  end
end
