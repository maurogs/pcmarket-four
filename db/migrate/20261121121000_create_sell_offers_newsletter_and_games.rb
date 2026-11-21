class CreateSellOffersNewsletterAndGames < ActiveRecord::Migration[8.1]
  def change
    create_table :sell_offers do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :item_kind, null: false, default: 0
      t.string :item_name, null: false
      t.string :condition
      t.integer :offered_price_cents, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.text :notes

      t.timestamps
    end

    add_index :sell_offers, :status
    add_index :sell_offers, :item_kind

    create_table :newsletter_subscribers do |t|
      t.string :email, null: false
      t.string :locale, null: false, default: "es"
      t.string :token, null: false
      t.datetime :confirmed_at
      t.datetime :unsubscribed_at

      t.timestamps
    end

    add_index :newsletter_subscribers, "lower(email)", unique: true,
              name: "index_newsletter_subscribers_on_lower_email"
    add_index :newsletter_subscribers, :token, unique: true
    add_index :newsletter_subscribers, :confirmed_at

    create_table :games do |t|
      t.string :slug, null: false
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :games, :slug, unique: true
    add_index :games, [ :active, :position ]
  end
end
