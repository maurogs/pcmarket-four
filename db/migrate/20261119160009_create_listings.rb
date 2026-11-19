class CreateListings < ActiveRecord::Migration[8.1]
  # Maintains listings.searchable: a weighted tsvector ('simple' config, with
  # unaccent applied). Only alphanumeric lexemes are indexed — this is what
  # makes "ps5", "4090" or "1tb" searchable even though the default text
  # search parser would split or discard them.
  SEARCH_FUNCTION = <<~SQL
    CREATE OR REPLACE FUNCTION listings_searchable_tsvector() RETURNS trigger
    LANGUAGE plpgsql AS $fn$
    DECLARE
      source record;
      word   text;
      parts  text := '';
      weight tsvector;
    BEGIN
      NEW.searchable := NULL;
      FOR source IN
        SELECT * FROM (VALUES
          (coalesce(NEW.title, '')::text, 'A'),
          (coalesce(NEW.specs::text, '')::text, 'B'),
          (coalesce(NEW.description, '')::text, 'C')
        ) AS s(txt, w)
      LOOP
        parts := '';
        FOR word IN
          SELECT DISTINCT w
          FROM ts_debug('simple'::regconfig, unaccent('unaccent', source.txt)) d,
               unnest(d.lexemes) w
          WHERE w ~ '^[[:alnum:]]+$'
        LOOP
          parts := parts || ' ' || word;
        END LOOP;
        IF parts <> '' THEN
          weight := setweight(to_tsvector('simple'::regconfig, parts), source.w::"char");
          NEW.searchable := COALESCE(NEW.searchable || weight, weight);
        END IF;
      END LOOP;
      RETURN NEW;
    END
    $fn$;
  SQL

  SEARCH_TRIGGER = <<~SQL
    CREATE TRIGGER set_listings_searchable
    BEFORE INSERT OR UPDATE OF title, description, specs ON listings
    FOR EACH ROW EXECUTE FUNCTION listings_searchable_tsvector();
  SQL

  # Query-side config so user input gets the same accent folding (unaccent) as
  # the indexed lexemes. Mapped to [unaccent, simple] for word-like tokens.
  SEARCH_CONFIG = <<~SQL
    CREATE TEXT SEARCH CONFIGURATION listings_unaccented (COPY = simple);
    ALTER TEXT SEARCH CONFIGURATION listings_unaccented
      ALTER MAPPING FOR asciiword, asciihword, hword, hword_asciipart, hword_numpart,
        hword_part, numword, numhword, word, host, file
      WITH unaccent, simple;
  SQL

  def up
    enable_extension "pg_trgm"
    enable_extension "unaccent"

    create_table :listings do |t|
      t.references :store, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: { to_table: :categories }
      t.string :title, null: false
      t.string :slug, null: false
      t.text :description
      t.integer :price_cents, null: false, default: 0
      t.integer :original_price_cents
      t.string :currency, null: false, default: "EUR"
      # 0 new_sealed, 1 new_open_box, 2 used_like_new, 3 used_good,
      # 4 used_fair, 5 for_parts
      t.integer :condition, null: false, default: 0
      t.integer :quantity, null: false, default: 1
      # AASM state machine: draft, pending_review, published, rejected,
      # paused, sold, archived
      t.string :status, null: false, default: "draft"
      t.text :rejection_reason
      t.bigint :reviewed_by_id
      t.datetime :reviewed_at
      t.datetime :published_at
      t.datetime :sold_at
      # { "gpu_chipset": ["nvidia"], "memory_capacity": ["32gb"] } —
      # option values from FilterOption#value, always string or array.
      t.jsonb :specs, null: false, default: {}
      # Ordered highlight bullets / benchmark rows for the detail page.
      t.jsonb :highlights, null: false, default: []
      # 0 platform_label, 1 own_label, 2 pickup_only
      t.integer :shipping_method, null: false, default: 0
      t.integer :shipping_price_cents, null: false, default: 0
      t.boolean :free_shipping, null: false, default: false
      t.integer :ships_within_days, null: false, default: 3
      t.boolean :local_pickup, null: false, default: false
      t.integer :weight_grams
      t.decimal :length_cm, precision: 8, scale: 2
      t.decimal :width_cm, precision: 8, scale: 2
      t.decimal :height_cm, precision: 8, scale: 2
      t.references :country, foreign_key: true
      t.string :province
      t.string :city
      t.string :postal_code
      t.boolean :allow_offers, null: false, default: true
      # Paid "featured" boost until this time (gated by a feature flag).
      t.datetime :featured_until
      t.integer :views_count, null: false, default: 0
      t.integer :favorites_count, null: false, default: 0
      t.integer :watchers_count, null: false, default: 0
      # Weighted tsvector maintained by listings_searchable_tsvector().
      t.tsvector :searchable

      t.timestamps
    end

    add_foreign_key :listings, :users, column: :reviewed_by_id

    add_index :listings, :slug, unique: true
    add_index :listings, :searchable, using: :gin
    add_index :listings, :specs, using: :gin, opclass: :jsonb_path_ops
    add_index :listings, :title, using: :gin, opclass: :gin_trgm_ops
    add_index :listings, :featured_until

    # Listing browse paths (partial: only published rows matter).
    add_index :listings, [ :category_id, :published_at ], name: "idx_listings_category_published",
      where: "status = 'published'"
    add_index :listings, :price_cents, name: "idx_listings_price_published",
      where: "status = 'published'"
    add_index :listings, [ :status, :featured_until ], name: "idx_listings_featured",
      where: "status = 'published'"
    add_index :listings, [ :store_id, :status ]
    add_index :listings, [ :status, :updated_at ]

    execute SEARCH_FUNCTION
    execute SEARCH_TRIGGER
    execute SEARCH_CONFIG
  end

  def down
    execute "DROP TEXT SEARCH CONFIGURATION IF EXISTS listings_unaccented"
    execute "DROP TRIGGER IF EXISTS set_listings_searchable ON listings"
    execute "DROP FUNCTION IF EXISTS listings_searchable_tsvector()"
    drop_table :listings
    disable_extension "pg_trgm"
    disable_extension "unaccent"
  end
end
