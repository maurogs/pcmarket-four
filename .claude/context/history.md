# Change history

## 2026-11-19 — Phase 0 foundation (uncommitted)

Built the entire foundation layer: gems (devise, pundit, omniauth-google,
tailwindcss-rails 4, rails-i18n/devise-i18n, rack-attack, pg_search, pagy,
friendly_id, meta-tags, sitemap_generator, aasm, stripe, bullet, faker),
6-locale i18n with locale-prefixed routing, Countries, typed Settings +
AppSettings cache service, Tailwind v4 design system with self-hosted fonts,
layout (header/mega-nav/footer/toasts/drawer, theme toggle), restyled Devise
views, Pundit scaffold, CSP/rack-attack/bullet config, seeds, README and the
minitest suite (44 green).

Why: multi-country marketplace needs i18n + feature flags + design system
before any catalog work; strict CSP forced self-hosted fonts from public/.

Notable fixes along the way:
- OmniAuth callbacks moved outside the locale `scope` (Devise limitation).
- `Setting` cache invalidation: `after_commit` → `after_save/touch/destroy`
  so it fires under transactional fixtures.
- CSP nonce generator: random instead of `session.id` (nil when anonymous).
- Fonts: relative `./fonts/` URLs broken through Propshaft → woff2 in
  `public/fonts/` with absolute URLs.
- `bin/dev` unsets `BUNDLE_FORCE_RUBY_PLATFORM` (user's global bashrc export
  blocked the tailwind native gem); `bundle lock --add-platform x86_64-linux`.
- Removed broken `mirror.https://rubygems.org` bundler config.

Files: ~70 added/changed — see `git status` for the full list.
(`app/assets/tailwind/`, `public/fonts/`, `app/{controllers,models,services,policies,helpers,javascript,views}`,
`config/{locales,routes.rb,application.rb,importmap.rb,sitemap.rb,initializers/}`,
`db/`, `test/`, `Gemfile`, `bin/dev`, `README.md`, `.claude/context/`.)

## 2026-11-19 — Phase 1a catalog data model (uncommitted)

Added the catalog data layer only (no storefront views): 12 reversible
migrations, models, services, idempotent seeds and 71 new tests (115 total,
all green; rubocop clean).

- **Migrations** (`db/migrate/20261119160001..12`): Active Storage tables,
  categories (self-FK tree, native enum `kind`), filter_definitions
  (enum `input_type`), filter_options, category_filters, product_labels,
  seller_tags, stores (enum `kind`), listings (54 cols, enum `condition`/
  `shipping_method`, string AASM `status`), listing_labels,
  listing_seller_tags, friendly_id_slugs. `schema_format` switched to `:sql`
  — `db/structure.sql` is canonical now (`db/schema.rb` deleted).
- **Search**: trigger-maintained weighted tsvector `searchable`
  (A=title, B=specs values, C=description) built by plpgsql
  `listings_searchable_tsvector()` that runs `unaccent()` + `ts_debug` over a
  custom `listings_unaccented` text search config, keeping alphanumeric
  lexemes only. Query side: `Listing.matching` scope
  (`@@ websearch_to_tsquery('listings_unaccented', …)`) + `by_relevance`
  (`ts_rank`). **pg_search removed from the Gemfile** — its rank subselect
  broke facet/`count` composition and the `with_ranking` API doesn't exist
  in 2.4.0.
- **Listing lifecycle**: AASM 6 string-state machine
  (draft→pending_review→published↔rejected, published→sold, any→archived);
  editing a published listing (REVIEWABLE_FIELDS: title/description/
  price_cents/specs or image blob ids) fires `return_to_review` from an
  `after_save` when the `listing_auto_approve` setting is off.
- **Listings::Search service**: text + category-subtree + spec filters
  (`@>` containment, OR within a key / AND across keys), price/condition/
  shipping/local-pickup filters, 6 sorts (relevance = ts_rank), Pagy::Offset
  pagination, per-option facet counts (one grouped query per definition,
  computed with that dimension's filter excluded, cached 5 min keyed on
  params + data version), `with_includes` preloads to avoid N+1.
- **Models**: Category (recursive-CTE subtree helpers, effective filter
  definitions merging ancestors, listings_count refresh), FilterDefinition
  (machine-token `value` format validation), FilterOption, Store (slug,
  active_listings_count refresh), SpanishProvince (config/spanish_provinces.yml),
  Translatable concern (jsonb `*_translations`).
- **Services/jobs**: `Stores::EnsureForUser`, `Stores::RefreshActiveListingsCount`,
  `Categories::RefreshListingsCount` + after-commit jobs.
- **Seeds** `db/seeds/*.rb` (11 files, loaded in order): countries, settings,
  45-category tree, 35 filter definitions, 223 filter options, 129 category
  filters, labels, seller tags — all idempotent upserts; admin edits survive
  re-seed.
- **I18n**: new keys in all 6 locale files (enum labels under
  `activerecord.attributes.*`, custom `errors.messages.*`, `spanish_provinces:`);
  parity test green.
- **Tests**: model validation + AASM transition tests (incl. edit-returns-to-
  review and auto-approve), Listings::Search (accents, spec AND/OR, facets,
  sorts, no N+1, category descendants), seeds idempotency integration test,
  fixtures + `test/support/catalog_helpers.rb`; `Rails.cache.clear` between
  tests; test queue adapter `:test`.

Notable fixes along the way:
- jsonb column defaults must be Ruby literals (`default: {}`), string
  defaults produced `'"{}"'::jsonb` scalars.
- TS config token-type list must use real PG17 parser aliases (`asciiword`,
  `hword_part`, …) — invented names aborted the migration.
- `setweight(…, source.w::"char")` cast required in the trigger function.
- `Category#chain_ids_sql` must call `Category.sanitize_sql_array` (class
  method), not the instance-level one.
- `normalize_specs` moved to `before_validation` (String defaults crashed
  `specs_are_valid`).
- Rails 8.1 `errors` is not lazy: always call `valid?` before reading
  `errors[:attr]` in tests.

Files: ~90 added/changed — `db/migrate/`, `db/seeds/`, `db/structure.sql`,
`app/{models,services,jobs}`, `app/models/listing.rb`, `config/locales/*`,
`config/application.rb`, `config/environments/test.rb`, `config/spanish_provinces.yml`,
`test/`, `Gemfile`, `README.md` (Troubleshooting + roadmap).

## 2026-11-19 — Phase 1a review fix: labels & seller tags reseed (uncommitted)

Rewrote `db/seeds/10_labels_and_tags.rb` to spec: 13 ProductLabels
(value/mid_range/pro_gamer per pcs/gpus/cpus, featured, rare, free_shipping,
deal — each slug + color + 6-locale names) and 20 SellerTags as *build
aesthetic* tags (anime…wood), not seller badges. Old slugs (`value`,
`mid_range`, `pro_gamer`, `verified`, `top_rated`, `quick_shipping`,
`business`) are deleted by slug on seed. Seller verification remains the
`Store#verified` boolean. `db/seeds.rb` summary line is now silent under
`Rails.env.test?`. Seeds idempotency test asserts the new 13/20 counts and
old-slug removal.

Also fixed a latent gap found while deleting: the `listing_labels` /
`listing_seller_tags` join **models** were missing (tables existed; the
`with_labels`/`with_seller_tags` scopes would have raised NameError). Added
`app/models/listing_label.rb`, `app/models/listing_seller_tag.rb` + a
scope test. db:seed ×2 idempotent; 116 tests green; rubocop clean.
