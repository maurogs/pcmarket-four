class DeviseCreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      ## Database authenticatable
      t.string :email, null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      ## Recoverable
      t.string :reset_password_token
      t.datetime :reset_password_sent_at

      ## Rememberable
      t.datetime :remember_created_at

      ## Trackable
      t.integer :sign_in_count, null: false, default: 0
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string :current_sign_in_ip
      t.string :last_sign_in_ip

      ## Confirmable
      t.string :confirmation_token
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.string :unconfirmed_email

      ## Lockable
      t.integer :failed_attempts, null: false, default: 0
      t.string :unlock_token
      t.datetime :locked_at

      ## Profile
      t.string :first_name
      t.string :last_name
      t.string :username, null: false
      t.string :phone
      t.integer :role, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.string :country_code, null: false, default: "ES"
      t.references :region, foreign_key: true
      t.string :city
      t.string :locale, null: false, default: "es"
      t.string :provider
      t.string :uid
      t.boolean :accepts_marketing, null: false, default: false
      t.datetime :terms_accepted_at
      t.datetime :deleted_at
      t.datetime :last_seen_at

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, :confirmation_token, unique: true
    add_index :users, :unlock_token, unique: true
    add_index :users, "lower(username)", unique: true, name: "index_users_on_lower_username"
    add_index :users, [ :provider, :uid ], unique: true, where: "provider IS NOT NULL AND uid IS NOT NULL"
    add_index :users, :role
    add_index :users, :status
    add_index :users, :deleted_at
    add_index :users, :country_code

    add_foreign_key :users, :countries, column: :country_code, primary_key: :code
  end
end
