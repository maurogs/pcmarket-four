# PCMarket — Project Context

_Last updated: 2026-11-19 (Phase 1a catalog data model complete, uncommitted)_

## What this is

Multi-country tech marketplace (classifieds → listings → auctions) on
Rails 8.1 / Ruby 4.0 / PostgreSQL / Tailwind v4 / Hotwire. Spain first;
FR/GB/DE/IT/PT seeded but disabled.

## Key decisions

- **Locales**: `[:en, :es, :fr, :de, :it, :pt]`, default `:es`; fallbacks map
  every non-es locale straight to `:en` (`config.i18n.fallbacks`). Locale
  resolution: param > signed cookie (`pcmarket_locale`) > Accept-Language >
  default, in `LocaleConcern`. Routes wrapped in `scope "(:locale)"`.
- **One locale file per language** (`config/locales/<locale>.yml`) containing
  app strings **and** a small custom `devise:` subtree; standard Devise strings
  come from the devise-i18n gem (`devise.en.yml` was deleted). Parity enforced
  by `test/i18n_keys_test.rb`.
- **OmniAuth routes live outside the locale scope** — Devise rejects
  omniauth callbacks under dynamic segments. `devise_for … only: :omniauth_callbacks`
  sits above the scope, the rest inside.
- **Countries**: ISO `code` is the PK-ish lookup (`to_param`), i18n `name_key`,
  `default_locale`, `enabled`, `launched_at` required when enabled. Current
  country = signed cookie > enabled country matching locale > first enabled
  (set in ApplicationController into `Current`).
- **Settings/feature flags**: `Setting` model (jsonb `value`, `value_type`
  casting via `typed_value`) + `AppSettings` service on `Rails.cache`
  (`app_settings/<key>`, `app_settings/all`). Cache invalidation uses
  `after_save/touch/destroy` (NOT `after_commit` — that never fires under
  transactional fixtures).
- **Fonts self-hosted** (Fraunces + Inter variable woff2, latin + latin-ext) in
  `public/fonts/`, `@font-face` in `app/assets/tailwind/fonts.css`; absolute
  `/fonts/...` URLs because neither Tailwind nor Propshaft rewrites relative
  URLs out of `app/assets/tailwind`. CSP stays `'self'`-only.
- **CSP nonces** use a random generator (`SecureRandom`) — `session.id` is nil
  for anonymous requests and produced empty nonces.
- **Google OAuth env-gated**: `GOOGLE_CLIENT_ID/SECRET`; helper
  `google_oauth_enabled?` hides the button when unset.
- **Bundler quirk**: user's `~/.bashrc` exports `BUNDLE_FORCE_RUBY_PLATFORM=true`
  (left untouched); `bin/dev` unsets it and the lock file has `x86_64-linux`
  so tailwindcss-ruby's native binary installs. A broken `mirror.https://`
  bundler config was removed earlier (was breaking `bundle install`).
- Devise: confirmable + lockable (10 attempts, 1h unlock), username optional
  (auto-generated from email/name), `User.from_omniauth` auto-confirms.
- **Schema is `:sql`** (`config/application.rb`) — `db/structure.sql` is
  canonical, `db/schema.rb` deleted. The search trigger/function/config are
  migration SQL (schema dumper round-trips them).
- **Search = Postgres, no gem**: trigger-maintained weighted tsvector
  `listings.searchable` (A=title, B=specs values, C=description) built by
  plpgsql `listings_searchable_tsvector()` looping
  `ts_debug('listings_unaccented', …)` (custom config = unaccent dict,
  alphanumeric token types only). Query: `Listing.matching`
  (`websearch_to_tsquery`) and `by_relevance` (`ts_rank`). **pg_search was
  removed** — rank subselect breaks `count`/facet composition,
  `with_ranking:` doesn't exist in 2.4.0.
- **Listing moderation**: AASM 6, **string** status column (default
  `draft`). States: draft/pending_review/published/rejected/archived + sold.
  Editing a published listing (REVIEWABLE_FIELDS title/description/
  price_cents/specs or image blob ids) auto-fires `return_to_review` from
  `after_save` unless `listing_auto_approve` flag is on; before/after image
  snapshot in `before_save`.
- **Specs filters**: `specs` jsonb `{ key => [values] }`; DB filter is
  `@>` containment — OR within a key, AND across keys (Arel-built).
  `FilterOption#value` is a machine token `/\A[a-z0-9][a-z0-9._-]*\z/`;
  display labels live in `label_translations` (real words translated,
  brands verbatim).
- **`Listings::Search` service** owns browse/search: params-hash in → records
  (Pagy::Offset) + total + facets out. Facet counts per option via one
  grouped query per definition (dimension's own filter excluded), cached
  5 min keyed on params + data-version stamp. SORTS: relevance, best_match,
  newest, price_asc, price_desc, most_watched.
- **Native integer enums** used for: `category.kind`,
  `filter_definition.input_type`, `store.kind`, `listing.condition`,
  `listing.shipping_method`. Enum labels i18n'd at
  `activerecord.attributes.<model>.<column_plural>.<value>`.
- **Counters**: `Category#listings_count`, `Store#active_listings_count`
  refreshed by services (`Categories::RefreshListingsCount`,
  `Stores::RefreshActiveListingsCount`) from after-commit jobs.
- **Seeds**: `db/seeds/*.rb` (11 files, numeric prefix order via
  `db/seeds.rb`), all upserts by natural key (`seed_record`) — idempotent,
  admin edits survive re-seed; obsolete slugs are deleted by slug. Summary
  `puts` is silenced under `Rails.env.test?`.
- Gotchas: jsonb migration defaults must be Ruby literals (`default: {}`,
  `default: []`); TS token-type aliases must exist in PG17 (`asciiword`,
  `hword_part`, … — old `part_hyphen` etc. don't); `setweight` needs
  `source.w::"char"` cast; Rails 8.1 `errors` is not lazy — call `valid?`
  before `errors[:attr]`; `sanitize_sql_array` is a class method.

## Code map (Phase 0)

- `app/controllers/concerns/locale_concern.rb` — locale + cookie logic.
- `app/controllers/application_controller.rb` — Pundit base, `Current.user/country`,
  locale/country resolution, devise param sanitizer, CSRF except json.
- `app/controllers/{home,pages,searches,sell_to_us,newsletter_subscribers}_controller.rb`
  (+ `users/omniauth_callbacks_controller.rb`). Pages use a `PAGES` allowlist;
  sell-to-us is flag-gated via `AppSettings.enabled?`.
- `app/models/` — `country`, `setting`, `user`, `current`.
- `app/services/app_settings.rb` — cached typed/localized reads.
- `app/policies/application_policy.rb` — Pundit scaffold.
- `app/helpers/` — `icon_helper` (inline SVG set), `locale_helper`, app helper
  (nav taxonomy `nav_categories`, `category_label/path`, `google_oauth_enabled?`).
- Views: `layouts/application` + `shared/` (announcement bar, header/mega-nav,
  mobile drawer, footer + newsletter, toasts), restyled `devise/`, `home/`,
  `pages/`, `searches/`, `sell_to_us/`.
- `app/javascript/controllers/` — `theme_toggle`, `dropdown`, `drawer`, `toast`.
- `app/assets/tailwind/application.css` — design tokens + `btn`/`input-field`/
  `card`/`section-title` utilities; `fonts.css` imported.
- Initializers: `devise` (mailer sender from ENV, lockable, google omniauth),
  `rack_attack`, `content_security_policy` (strict, report-only in dev),
  `omniauth` (POST request phase), `bullet` (dev, off via env).
- `config/sitemap.rb` + `GET /sitemaps` controller-less redirect → per-locale sitemap.
- Seeds are idempotent (`seed_record` upsert by natural key).

## Code map (Phase 1a — catalog data model)

- `app/models/category.rb` — tree (`parent_id`), recursive-CTE subtree
  helpers, `effective_filter_definitions` (own + inherited), listings_count.
- `app/models/{filter_definition,filter_option,category_filter}.rb` —
  spec vocabulary: keys, machine-token values, per-category assignment
  (join model `category_filter.rb`).
- `app/models/listing.rb` — the big one: AASM machine, validations,
  `matching`/`by_relevance`/`in_category`/`specs_where` scopes, re-review on
  edit, `with_includes` preloads, `display_price`.
- `app/models/{store,product_label,seller_tag,spanish_province}.rb` +
  join models `listing_label.rb` / `listing_seller_tag.rb` +
  `app/models/concerns/translatable.rb` (jsonb `*_translations`,
  `translated_name`). ProductLabel = marketing badges (13 seeded, e.g.
  `value_gpus`, `deal`); SellerTag = build aesthetic tags (20 seeded, e.g.
  `rgb`, `sakura`) — seller trust is `Store#verified`, not a tag.
- `app/services/listings/search.rb` — browse/search pipeline (filters,
  sorts, facets, Pagy). `app/services/app_settings.rb` gains
  `enabled?(key)`.
- `app/services/{stores,categories}/*.rb` + `app/jobs/{stores,categories}/*.rb`
  — counter refreshes and default-store creation.
- `db/migrate/20261119160001..12_*.rb` (12), `db/structure.sql`,
  `db/seeds/{01..10}*.rb`, `config/spanish_provinces.yml`.
- Tests: `test/models/{category,store,filter_definition,spanish_province,listing}_test.rb`,
  `test/services/listings/search_test.rb`,
  `test/integration/seeds_idempotency_test.rb`, fixtures +
  `test/support/catalog_helpers.rb`.

## Testing

- `bin/rails test` — **116 tests green**: all Phase 0 checks plus model
  validations, AASM transitions (incl. edit-returns-to-review and
  auto-approve), search (accents, spec AND/OR, price/condition filters,
  sorts, facets, N+1, category descendants), seeds idempotency (twice +
  admin-edit survival), i18n parity.
- Acceptance: `bin/rails db:migrate:redo STEP=12` + `db:migrate` + `db:seed`
  ×2 verified clean.
- Remember `env -u BUNDLE_FORCE_RUBY_PLATFORM` for any bundler/rake command
  run outside `bin/dev`; export `TAILWINDCSS_INSTALL_DIR` (see README
  Troubleshooting) when the tailwind binary isn't found.

## Open items

- Phase 1b: storefront views (category browse, listing detail, publish
  flow, seller dashboard) on top of the 1a model/service layer.
- Admin UI for categories/filters/labels/settings (seeds cover data now).
- Wishlist/notifications/cart are `#` placeholders in the header.
- CI not set up yet.
- No commit made for Phase 1a (or 0) — awaiting user review.
