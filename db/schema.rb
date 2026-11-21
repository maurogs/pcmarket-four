# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_22_100100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"
  enable_extension "unaccent"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "addresses", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "full_name", null: false
    t.string "line1", null: false
    t.string "line2"
    t.string "city", null: false
    t.string "postal_code", null: false
    t.bigint "region_id"
    t.string "country_code", null: false
    t.string "phone"
    t.boolean "default", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["region_id"], name: "index_addresses_on_region_id"
    t.index ["user_id", "default"], name: "index_addresses_on_user_id_and_default"
    t.index ["user_id"], name: "index_addresses_on_user_id"
  end

  create_table "admin_audit_logs", force: :cascade do |t|
    t.bigint "admin_id", null: false
    t.string "action", null: false
    t.string "auditable_type"
    t.bigint "auditable_id"
    t.jsonb "changeset", default: {}, null: false
    t.string "ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_admin_audit_logs_on_action"
    t.index ["admin_id"], name: "index_admin_audit_logs_on_admin_id"
    t.index ["auditable_type", "auditable_id"], name: "index_admin_audit_logs_on_auditable"
    t.index ["created_at"], name: "index_admin_audit_logs_on_created_at"
  end

  create_table "api_tokens", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token", null: false
    t.string "name"
    t.datetime "last_used_at"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_api_tokens_on_expires_at"
    t.index ["token"], name: "index_api_tokens_on_token", unique: true
    t.index ["user_id"], name: "index_api_tokens_on_user_id"
  end

  create_table "blocks", force: :cascade do |t|
    t.bigint "blocker_id", null: false
    t.bigint "blocked_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["blocked_id"], name: "index_blocks_on_blocked_id"
    t.index ["blocker_id", "blocked_id"], name: "index_blocks_on_blocker_id_and_blocked_id", unique: true
    t.index ["blocker_id"], name: "index_blocks_on_blocker_id"
  end

  create_table "cart_items", force: :cascade do |t|
    t.bigint "user_id"
    t.string "cart_token"
    t.bigint "listing_id", null: false
    t.integer "quantity", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cart_token", "listing_id"], name: "index_cart_items_on_cart_token_and_listing_id", unique: true, where: "(cart_token IS NOT NULL)"
    t.index ["cart_token"], name: "index_cart_items_on_cart_token"
    t.index ["listing_id"], name: "index_cart_items_on_listing_id"
    t.index ["user_id", "listing_id"], name: "index_cart_items_on_user_id_and_listing_id", unique: true, where: "(user_id IS NOT NULL)"
    t.index ["user_id"], name: "index_cart_items_on_user_id"
    t.check_constraint "(user_id IS NOT NULL) <> (cart_token IS NOT NULL)", name: "cart_items_exactly_one_owner"
  end

  create_table "categories", force: :cascade do |t|
    t.jsonb "names", default: {}, null: false
    t.string "slug", null: false
    t.string "ancestry"
    t.integer "position", default: 0, null: false
    t.string "icon"
    t.boolean "active", default: true, null: false
    t.boolean "show_in_menu", default: false, null: false
    t.string "menu_group"
    t.jsonb "seo_descriptions", default: {}, null: false
    t.integer "listings_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active", "position"], name: "index_categories_on_active_and_position"
    t.index ["ancestry"], name: "index_categories_on_ancestry"
    t.index ["menu_group"], name: "index_categories_on_menu_group"
    t.index ["show_in_menu", "menu_group"], name: "index_categories_on_show_in_menu_and_menu_group"
    t.index ["slug"], name: "index_categories_on_slug", unique: true
  end

  create_table "category_filters", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.bigint "filter_definition_id", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id", "filter_definition_id"], name: "index_category_filters_on_category_and_definition", unique: true
    t.index ["category_id"], name: "index_category_filters_on_category_id"
    t.index ["filter_definition_id"], name: "index_category_filters_on_filter_definition_id"
  end

  create_table "conversations", force: :cascade do |t|
    t.bigint "listing_id"
    t.bigint "buyer_id", null: false
    t.bigint "seller_id", null: false
    t.datetime "last_message_at"
    t.integer "buyer_unread_count", default: 0, null: false
    t.integer "seller_unread_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["buyer_id", "last_message_at"], name: "index_conversations_on_buyer_id_and_last_message_at"
    t.index ["buyer_id"], name: "index_conversations_on_buyer_id"
    t.index ["listing_id", "buyer_id", "seller_id"], name: "index_conversations_on_listing_and_participants", unique: true
    t.index ["listing_id"], name: "index_conversations_on_listing_id"
    t.index ["seller_id", "last_message_at"], name: "index_conversations_on_seller_id_and_last_message_at"
    t.index ["seller_id"], name: "index_conversations_on_seller_id"
  end

  create_table "countries", force: :cascade do |t|
    t.string "code", null: false
    t.string "name_key", null: false
    t.boolean "enabled", default: false, null: false
    t.string "currency", default: "EUR", null: false
    t.decimal "vat_rate", precision: 5, scale: 2
    t.string "default_locale", default: "es", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_countries_on_code", unique: true
    t.index ["enabled"], name: "index_countries_on_enabled"
  end

  create_table "favorites", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "listing_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["listing_id"], name: "index_favorites_on_listing_id"
    t.index ["user_id", "listing_id"], name: "index_favorites_on_user_id_and_listing_id", unique: true
    t.index ["user_id"], name: "index_favorites_on_user_id"
  end

  create_table "filter_definitions", force: :cascade do |t|
    t.string "key", null: false
    t.jsonb "names", default: {}, null: false
    t.integer "input_type", default: 0, null: false
    t.string "unit"
    t.integer "position", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active", "position"], name: "index_filter_definitions_on_active_and_position"
    t.index ["key"], name: "index_filter_definitions_on_key", unique: true
  end

  create_table "filter_options", force: :cascade do |t|
    t.bigint "filter_definition_id", null: false
    t.string "value", null: false
    t.jsonb "labels", default: {}, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["filter_definition_id", "value"], name: "index_filter_options_on_filter_definition_id_and_value", unique: true
    t.index ["filter_definition_id"], name: "index_filter_options_on_filter_definition_id"
  end

  create_table "follows", force: :cascade do |t|
    t.bigint "follower_id", null: false
    t.bigint "store_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["follower_id", "store_id"], name: "index_follows_on_follower_id_and_store_id", unique: true
    t.index ["follower_id"], name: "index_follows_on_follower_id"
    t.index ["store_id"], name: "index_follows_on_store_id"
  end

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.string "scope"
    t.datetime "created_at"
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_id"
  end

  create_table "games", force: :cascade do |t|
    t.string "slug", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active", "position"], name: "index_games_on_active_and_position"
    t.index ["slug"], name: "index_games_on_slug", unique: true
  end

  create_table "legal_pages", force: :cascade do |t|
    t.string "slug", null: false
    t.string "country_code"
    t.string "locale", default: "es", null: false
    t.string "title", null: false
    t.text "body", null: false
    t.integer "version", default: 1, null: false
    t.boolean "published", default: true, null: false
    t.bigint "updated_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["published", "locale"], name: "index_legal_pages_on_published_and_locale"
    t.index ["slug", "country_code", "locale"], name: "index_legal_pages_on_slug_and_country_code_and_locale", unique: true
    t.index ["slug"], name: "index_legal_pages_on_slug"
    t.index ["updated_by_id"], name: "index_legal_pages_on_updated_by_id"
  end

  create_table "listings", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "store_id"
    t.bigint "category_id", null: false
    t.string "title", null: false
    t.string "slug", null: false
    t.text "description", null: false
    t.integer "price_cents", default: 0, null: false
    t.integer "original_price_cents"
    t.string "currency", default: "EUR", null: false
    t.integer "condition", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.text "rejection_reason"
    t.datetime "published_at"
    t.datetime "reviewed_at"
    t.bigint "reviewed_by_id"
    t.integer "quantity", default: 1, null: false
    t.jsonb "specs", default: {}, null: false
    t.string "brand"
    t.string "model_name_text"
    t.string "country_code", default: "ES", null: false
    t.bigint "region_id"
    t.string "city"
    t.string "postal_code"
    t.boolean "shipping_available", default: true, null: false
    t.boolean "local_pickup", default: false, null: false
    t.integer "shipping_price_cents", default: 0, null: false
    t.boolean "free_shipping", default: false, null: false
    t.integer "ships_within_days", default: 3, null: false
    t.boolean "accepts_offers", default: false, null: false
    t.datetime "featured_until"
    t.integer "views_count", default: 0, null: false
    t.integer "favorites_count", default: 0, null: false
    t.string "labels", default: [], null: false, array: true
    t.string "tags", default: [], null: false, array: true
    t.integer "performance_score"
    t.jsonb "game_fps", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["brand"], name: "index_listings_on_brand"
    t.index ["category_id", "status"], name: "index_listings_on_category_id_and_status"
    t.index ["category_id"], name: "index_listings_on_category_id"
    t.index ["condition"], name: "index_listings_on_condition"
    t.index ["country_code", "status"], name: "index_listings_on_country_code_and_status"
    t.index ["country_code"], name: "index_listings_on_country_code"
    t.index ["description"], name: "index_listings_on_description", opclass: :gin_trgm_ops, using: :gin
    t.index ["featured_until"], name: "index_listings_on_featured_until"
    t.index ["labels"], name: "index_listings_on_labels", using: :gin
    t.index ["price_cents"], name: "index_listings_on_price_cents"
    t.index ["published_at"], name: "index_listings_on_published_at"
    t.index ["region_id"], name: "index_listings_on_region_id"
    t.index ["reviewed_by_id"], name: "index_listings_on_reviewed_by_id"
    t.index ["slug"], name: "index_listings_on_slug", unique: true
    t.index ["specs"], name: "index_listings_on_specs", using: :gin
    t.index ["status", "category_id", "published_at"], name: "index_listings_search_category", order: { published_at: :desc }
    t.index ["status", "favorites_count"], name: "index_listings_search_popular", order: { favorites_count: :desc }
    t.index ["status", "price_cents"], name: "index_listings_search_price"
    t.index ["status", "published_at"], name: "index_listings_on_status_and_published_at"
    t.index ["status", "published_at"], name: "index_listings_published_feed", order: { published_at: :desc }, where: "((status = 2) AND (quantity > 0))"
    t.index ["status", "region_id", "published_at"], name: "index_listings_search_region", order: { published_at: :desc }
    t.index ["status", "store_id", "published_at"], name: "index_listings_search_store", order: { published_at: :desc }
    t.index ["status"], name: "index_listings_on_status"
    t.index ["store_id"], name: "index_listings_on_store_id"
    t.index ["tags"], name: "index_listings_on_tags", using: :gin
    t.index ["title"], name: "index_listings_on_title", opclass: :gin_trgm_ops, using: :gin
    t.index ["user_id"], name: "index_listings_on_user_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.bigint "sender_id", null: false
    t.text "body", null: false
    t.integer "kind", default: 0, null: false
    t.integer "offer_amount_cents"
    t.integer "offer_status"
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id", "created_at"], name: "index_messages_on_conversation_id_and_created_at"
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["read_at"], name: "index_messages_on_read_at"
    t.index ["sender_id"], name: "index_messages_on_sender_id"
  end

  create_table "newsletter_subscribers", force: :cascade do |t|
    t.string "email", null: false
    t.string "locale", default: "es", null: false
    t.string "token", null: false
    t.datetime "confirmed_at"
    t.datetime "unsubscribed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((email)::text)", name: "index_newsletter_subscribers_on_lower_email", unique: true
    t.index ["confirmed_at"], name: "index_newsletter_subscribers_on_confirmed_at"
    t.index ["token"], name: "index_newsletter_subscribers_on_token", unique: true
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "kind", null: false
    t.jsonb "params", default: {}, null: false
    t.string "url"
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_notifications_on_created_at"
    t.index ["user_id", "read_at"], name: "index_notifications_on_user_id_and_read_at"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "order_events", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "actor_id"
    t.string "kind", null: false
    t.jsonb "data", default: {}, null: false
    t.datetime "created_at", null: false
    t.index ["actor_id"], name: "index_order_events_on_actor_id"
    t.index ["order_id", "created_at"], name: "index_order_events_on_order_id_and_created_at"
    t.index ["order_id"], name: "index_order_events_on_order_id"
  end

  create_table "order_items", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "listing_id", null: false
    t.string "title_snapshot", null: false
    t.integer "price_cents", null: false
    t.integer "quantity", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["listing_id"], name: "index_order_items_on_listing_id"
    t.index ["order_id", "listing_id"], name: "index_order_items_on_order_id_and_listing_id", unique: true
    t.index ["order_id"], name: "index_order_items_on_order_id"
  end

  create_table "orders", force: :cascade do |t|
    t.string "number", null: false
    t.bigint "buyer_id"
    t.bigint "seller_id", null: false
    t.bigint "store_id"
    t.integer "status", default: 0, null: false
    t.integer "fulfilment", default: 0, null: false
    t.integer "subtotal_cents", default: 0, null: false
    t.integer "shipping_cents", default: 0, null: false
    t.integer "commission_cents", default: 0, null: false
    t.decimal "commission_percent", precision: 5, scale: 2
    t.integer "total_cents", default: 0, null: false
    t.string "currency", default: "EUR", null: false
    t.string "ship_name"
    t.string "ship_line1"
    t.string "ship_line2"
    t.string "ship_city"
    t.string "ship_postal_code"
    t.string "ship_region"
    t.string "ship_country_code"
    t.string "ship_phone"
    t.string "buyer_email"
    t.string "tracking_number"
    t.string "carrier"
    t.datetime "paid_at"
    t.datetime "shipped_at"
    t.datetime "delivered_at"
    t.datetime "completed_at"
    t.datetime "cancelled_at"
    t.text "cancel_reason"
    t.string "payment_provider"
    t.string "payment_reference"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "payment_method"
    t.string "locale", default: "es", null: false
    t.string "checkout_token"
    t.string "guest_access_token"
    t.datetime "terms_accepted_at"
    t.datetime "stock_restored_at"
    t.datetime "disputed_at"
    t.datetime "refunded_at"
    t.boolean "refund_required", default: false, null: false
    t.datetime "late_shipment_notified_at"
    t.index ["buyer_id", "created_at"], name: "index_orders_on_buyer_id_and_created_at"
    t.index ["buyer_id"], name: "index_orders_on_buyer_id"
    t.index ["checkout_token", "seller_id"], name: "index_orders_on_checkout_token_and_seller", unique: true, where: "(checkout_token IS NOT NULL)"
    t.index ["disputed_at"], name: "index_orders_on_disputed_at"
    t.index ["fulfilment"], name: "index_orders_on_fulfilment"
    t.index ["guest_access_token"], name: "index_orders_on_guest_access_token", unique: true, where: "(guest_access_token IS NOT NULL)"
    t.index ["number"], name: "index_orders_on_number", unique: true
    t.index ["paid_at"], name: "index_orders_on_paid_at"
    t.index ["seller_id", "created_at"], name: "index_orders_on_seller_id_and_created_at"
    t.index ["seller_id"], name: "index_orders_on_seller_id"
    t.index ["status"], name: "index_orders_on_status"
    t.index ["store_id"], name: "index_orders_on_store_id"
  end

  create_table "regions", force: :cascade do |t|
    t.string "country_code", null: false
    t.string "name", null: false
    t.string "code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["country_code", "name"], name: "index_regions_on_country_code_and_name", unique: true
    t.index ["country_code"], name: "index_regions_on_country_code"
  end

  create_table "reports", force: :cascade do |t|
    t.bigint "reporter_id", null: false
    t.string "reportable_type", null: false
    t.bigint "reportable_id", null: false
    t.integer "reason", default: 0, null: false
    t.text "details"
    t.integer "status", default: 0, null: false
    t.bigint "resolved_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reportable_type", "reportable_id"], name: "index_reports_on_reportable"
    t.index ["reportable_type", "reportable_id"], name: "index_reports_on_reportable_type_and_reportable_id"
    t.index ["reporter_id"], name: "index_reports_on_reporter_id"
    t.index ["resolved_by_id"], name: "index_reports_on_resolved_by_id"
    t.index ["status"], name: "index_reports_on_status"
  end

  create_table "reviews", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "reviewer_id", null: false
    t.bigint "store_id", null: false
    t.integer "rating", null: false
    t.text "body"
    t.text "seller_reply"
    t.boolean "published", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_reviews_on_order_id", unique: true
    t.index ["rating"], name: "index_reviews_on_rating"
    t.index ["reviewer_id"], name: "index_reviews_on_reviewer_id"
    t.index ["store_id", "published"], name: "index_reviews_on_store_id_and_published"
    t.index ["store_id"], name: "index_reviews_on_store_id"
  end

  create_table "saved_searches", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.string "query"
    t.bigint "category_id"
    t.jsonb "filters", default: {}, null: false
    t.integer "min_price_cents"
    t.integer "max_price_cents"
    t.string "country_code"
    t.boolean "notify", default: true, null: false
    t.datetime "last_notified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_saved_searches_on_category_id"
    t.index ["country_code"], name: "index_saved_searches_on_country_code"
    t.index ["user_id", "notify"], name: "index_saved_searches_on_user_id_and_notify"
    t.index ["user_id"], name: "index_saved_searches_on_user_id"
  end

  create_table "sell_offers", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "item_kind", default: 0, null: false
    t.string "item_name", null: false
    t.string "condition"
    t.integer "offered_price_cents", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_kind"], name: "index_sell_offers_on_item_kind"
    t.index ["status"], name: "index_sell_offers_on_status"
    t.index ["user_id"], name: "index_sell_offers_on_user_id"
  end

  create_table "settings", force: :cascade do |t|
    t.string "key", null: false
    t.text "value"
    t.string "value_type", default: "string", null: false
    t.string "group"
    t.string "description_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group"], name: "index_settings_on_group"
    t.index ["key"], name: "index_settings_on_key", unique: true
  end

  create_table "stores", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description"
    t.integer "store_type", default: 0, null: false
    t.boolean "verified", default: false, null: false
    t.string "tax_id"
    t.string "company_name"
    t.boolean "vacation_mode", default: false, null: false
    t.text "vacation_message"
    t.boolean "allow_offers_default", default: true, null: false
    t.decimal "rating_avg", precision: 3, scale: 2, default: "0.0", null: false
    t.integer "reviews_count", default: 0, null: false
    t.integer "followers_count", default: 0, null: false
    t.integer "sales_count", default: 0, null: false
    t.integer "listings_count", default: 0, null: false
    t.text "return_policy"
    t.text "shipping_policy"
    t.string "country_code"
    t.bigint "region_id"
    t.string "city"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["country_code"], name: "index_stores_on_country_code"
    t.index ["region_id"], name: "index_stores_on_region_id"
    t.index ["slug"], name: "index_stores_on_slug", unique: true
    t.index ["user_id"], name: "index_stores_on_user_id", unique: true
    t.index ["verified"], name: "index_stores_on_verified"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.string "first_name"
    t.string "last_name"
    t.string "username", null: false
    t.string "phone"
    t.integer "role", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.string "country_code", default: "ES", null: false
    t.bigint "region_id"
    t.string "city"
    t.string "locale", default: "es", null: false
    t.string "provider"
    t.string "uid"
    t.boolean "accepts_marketing", default: false, null: false
    t.datetime "terms_accepted_at"
    t.datetime "deleted_at"
    t.datetime "last_seen_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "notification_preferences", default: {}, null: false
    t.index "lower((username)::text)", name: "index_users_on_lower_username", unique: true
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["country_code"], name: "index_users_on_country_code"
    t.index ["deleted_at"], name: "index_users_on_deleted_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true, where: "((provider IS NOT NULL) AND (uid IS NOT NULL))"
    t.index ["region_id"], name: "index_users_on_region_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.index ["status"], name: "index_users_on_status"
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "addresses", "countries", column: "country_code", primary_key: "code"
  add_foreign_key "addresses", "regions"
  add_foreign_key "addresses", "users"
  add_foreign_key "admin_audit_logs", "users", column: "admin_id"
  add_foreign_key "api_tokens", "users"
  add_foreign_key "blocks", "users", column: "blocked_id"
  add_foreign_key "blocks", "users", column: "blocker_id"
  add_foreign_key "cart_items", "listings"
  add_foreign_key "cart_items", "users"
  add_foreign_key "category_filters", "categories"
  add_foreign_key "category_filters", "filter_definitions"
  add_foreign_key "conversations", "listings"
  add_foreign_key "conversations", "users", column: "buyer_id"
  add_foreign_key "conversations", "users", column: "seller_id"
  add_foreign_key "favorites", "listings"
  add_foreign_key "favorites", "users"
  add_foreign_key "filter_options", "filter_definitions"
  add_foreign_key "follows", "stores"
  add_foreign_key "follows", "users", column: "follower_id"
  add_foreign_key "legal_pages", "users", column: "updated_by_id"
  add_foreign_key "listings", "categories"
  add_foreign_key "listings", "countries", column: "country_code", primary_key: "code"
  add_foreign_key "listings", "regions"
  add_foreign_key "listings", "stores"
  add_foreign_key "listings", "users"
  add_foreign_key "listings", "users", column: "reviewed_by_id"
  add_foreign_key "messages", "conversations"
  add_foreign_key "messages", "users", column: "sender_id"
  add_foreign_key "notifications", "users"
  add_foreign_key "order_events", "orders"
  add_foreign_key "order_events", "users", column: "actor_id"
  add_foreign_key "order_items", "listings"
  add_foreign_key "order_items", "orders"
  add_foreign_key "orders", "stores"
  add_foreign_key "orders", "users", column: "buyer_id"
  add_foreign_key "orders", "users", column: "seller_id"
  add_foreign_key "regions", "countries", column: "country_code", primary_key: "code"
  add_foreign_key "reports", "users", column: "reporter_id"
  add_foreign_key "reports", "users", column: "resolved_by_id"
  add_foreign_key "reviews", "orders"
  add_foreign_key "reviews", "stores"
  add_foreign_key "reviews", "users", column: "reviewer_id"
  add_foreign_key "saved_searches", "categories"
  add_foreign_key "saved_searches", "users"
  add_foreign_key "sell_offers", "users"
  add_foreign_key "stores", "regions"
  add_foreign_key "stores", "users"
  add_foreign_key "users", "countries", column: "country_code", primary_key: "code"
  add_foreign_key "users", "regions"
end
