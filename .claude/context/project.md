# PCMarket — Project Context

_Last updated: 2026-11-20 (Phase 4 step 2 — orders data model +
`Orders::Placer`; uncommitted)_

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
  snapshot in `before_save`. **AASM gotcha**: non-bang events only change
  the state in memory — persistence requires the bang event (`submit!` =
  `save!`, raises `ActiveRecord::RecordInvalid` on validation failure; no
  whiny_* config is used). Submitting/publishing additionally requires ≥1
  photo (`image_present_for_review`) + all required category specs.
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
- **Seeds**: `db/seeds/*.rb` (14 files, numeric prefix order via
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

## Code map (Phase 1b-i — browse & listing pages)

- Routes: `resources :categories, only: :show, path: "c", param: :slug` and
  `resources :listings, only: :show, path: "l"` inside the locale scope.
  Optional `(:locale)` segment has **no route default** (it would shadow
  cookie/Accept-Language negotiation); request-time paths carry the locale via
  `LocaleConcern#default_url_options` (`{ locale: I18n.locale }`), which also
  lets `category_path(record)` fill `:slug` positionally.
- `app/controllers/concerns/browseable.rb` — shared before_action that builds
  `@result` (Listings::Search) + `@page_title` for categories/search pages;
  `CategoriesController` and `SearchesController` both render
  `app/views/browse/_page` (band + sidebar + results turbo-frame).
- `Listings::Search::Result` gained `dimension_facets` (condition/labels/
  seller_tags counts), `filter_definitions`, `selected_filter_options`
  (pill labels, machine values cached locale-safely).
- `BrowseHelper` — sort options, pagination window, hidden filter fields,
  active-filter pills + removal/clear URLs, euro↔cents helpers; `ListingsHelper`
  — webp `<picture>` card images (per-request FilterDefinition memo, no N+1),
  spec chips/grouped table, location/shipping text; new icons in `IconHelper`.
- Stimulus: `filters` (euro inputs → hidden cents, debounced auto-submit),
  `show_more`, `carousel`, `wishlist` (placeholder).
- `app/views/browse/*` (page, band, sidebar, price_filter, facet_group/option,
  mobile_filters drawer, results, pagination), `app/views/listings/*` (show,
  card, gallery, scroller), `app/views/categories/show`.
- `ListingsController#show`: FriendlyId-history 301 on stale slugs, 404 unless
  `Listing#viewable_by?` (public | owner | admin, with preview banner),
  `fresh_when` (etag listing+locale, anonymous only), async
  `Listings::IncrementViewsCountJob` (1h dedupe per session/IP via
  Rails.cache), `@similar_listings`/`@more_from_store` (ids cached 10 min).
- Browse test catalog: `create_browse_catalog` in
  `test/support/catalog_helpers.rb` — created per test, **not fixtures**:
  fixture listings land in every test DB and broke the global-scope
  Search/count tests (also: fixture COPY skips INSERT triggers, so tsvector
  would need a backfill).

## Code map (Phase 1b-ii-a — mega menu, home, stores, demo seed)

- `app/services/navigation_menu.rb` — mega-menu builder (Struct
  Item/Column/Promo/Link, Marshal-safe) from Category tree + curated links
  (`BUDGET_LABELS` ProductLabel slugs, gpu_chipset FilterOptions,
  `THEME_TAGS`); cached per locale on `cache_stamp`
  (locale/Category#updated_at/sell-to-us flag); header + mobile drawer
  fragment-cache on the same stamp. `ApplicationHelper#nav_entry_path`
  replaced the old `nav_categories`/`category_label` taxonomy helpers.
- `app/services/home_page.rb` — home section id-lists (deals/newest/
  featured/recently-sold + tiles) cached ~6 min keyed on
  `Listing.maximum(:updated_at)` + locale; views reload via `#listings(ids)`
  (`with_includes`, `in_order_of`). `HomeController` exposes `@home` +
  `@sell_to_us_enabled`; `app/views/home/index.html.erb` renders carousel
  hero (static fallback), tiles, PC Finder banner, scrollers (`_scroller`
  partial), sell CTA, testimonials, trust strip → `/pages/trust` (new entry
  in `PagesController::PAGES` + `pages.titles.trust` in 6 locales).
- Stores: route `resources :stores, only: :show, path: "s", param: :slug` →
  `StoresController` (`tab` param listings|about|reviews, `render_not_found`
  on unknown slug) + `app/views/stores/show.html.erb` (header, stats,
  vacation banner w/ `store.vacation_message`, tabs inside
  `turbo-frame#browse_results` reusing browse partials). `Listings::Search`
  accepts `params["store"]` + `params["include_sold"]` (sold-last CASE in
  both sort paths); `Browseable#run_search(store:)` passes `include_sold: "1"`.
  `listings/_card` shows SOLD overlay + seller link (cache key `card/v2`).
- Stimulus: `mega_menu` (hover-intent open/close, Esc/arrows,
  aria-expanded), `hero_carousel` (autoplay, pause on hover/focus, dots,
  keyboard).
- `db/seeds.rb` loads `db/seeds/development/*.rb` **only** when
  `Rails.env.development? && ENV["DEMO"] == "1"` (README "Demo data"
  section); `db/seeds/development/demo.rb` self-skips once ≥200 demo
  listings exist. Demo emails are `%@demo.example.com`.

## Code map (Phase 1b-ii-b — PC Finder step 1: games + performance scores)

- `app/models/game.rb` — PC Finder catalog game: `demand` jsonb benchmark
  targets (`required_score(resolution, fps)`), `cpu_weight`, `active`
  scope (position order), `has_one_attached :image`.
- `filter_options.performance_score` / `listings.performance_score`
  (integer, nullable; partial index `idx_listings_status_performance_score`).
- `app/services/listings/performance_scorer.rb` — gpu score from the
  `gpu_model` FilterOption, blended with `cpu_model` as `gpu*0.7 + cpu*0.3`
  (nil without a scored GPU); `Listing` assigns it in `before_save` when
  specs change.

## Code map (Phase 1b-ii-b — PC Finder step 2: score + game seeds)

- `db/seeds/11_performance_scores.rb` — `GPU_SCORES` slug→tier map (only
  written when the option's score is nil; covers unseeded 50-series/GTX
  slugs), `cpu_model` FilterDefinition (sidebar off, sell form on) + 29
  scored CPU options, CategoryFilter → gaming-pcs/workstations/cpus.
- `db/seeds/12_games.rb` — 10 Game rows, `demand` on the 0–100 GPU scale
  (>100 = unattainable target). `db/seeds/13_backfill_performance_scores.rb`
  — `update_column` backfill via the scorer.
- `db/seeds/development/demo.rb` — gaming PCs/workstations always get
  `gpu_model` + `cpu_model` specs (`system_spec_values` pre-computed).

## Code map (Phase 1b-ii-c — PC Finder step 3: query + recommender services)

- `app/services/pc_finder/query.rb` — `PcFinder::Query` value object:
  sanitized selections (≤3 active games, resolution/fps/budget/case_pref/
  cooling/vibe/sort/page allowlists, silent default fallbacks),
  `budget_price_range` cents, `present?`, `to_params` for URLs.
- `app/services/pc_finder/recommender.rb` — `PcFinder::Recommender`:
  visible gaming-pcs subtree with `performance_score >=` max game
  `required_score`; hard filters budget / `cpu_cooler_type`
  (`air`,`aio-liquid`) / compact `case_form_factor`
  (`mini-itx-sff`,`micro-atx`,`mini-tower`); soft vibe + `case_color`
  boosts in best_match SQL (matches DESC, headroom-per-euro DESC);
  Pagy::Offset limit 24; `Result#estimated_fps` capped at 360.

## Code map (Phase 1b-ii-c — PC Finder step 4: route, controller & views)

- Route `resource :pc_finder, only: :show, path: "pc-finder"` (locale
  scope) → `PcFindersController#show` (`@query`/`@result`/`@games`).
- `app/views/pc_finders/{show,_quiz,_step,_results,_performance}.html.erb`:
  one GET quiz form (`data-controller="quiz"`, step/dot/back/next/submit
  targets, `data-quiz-step-value` from `?step`, all fieldsets visible
  without JS), results = summary chips (`to_params` + `step:`), sort form
  reusing the `filters` controller, `listings/card` + `browse/pagination`
  reuse, per-card FPS block (green ≥ target / amber below); no-params
  tiles → gaming-pcs `seller_tags` browse + `pc_finder_path(games:)`.
  I18n under `pc_finders.show.*` in all 6 locales (quoted `800_1200`-style
  YAML keys — Psych would parse them as ints otherwise).
- `app/javascript/controllers/quiz_controller.js` (step 5): steps through the
  fieldsets (1-based `step` value → zero-based index), dot/aria-current
  styling, Back/Next/Submit visibility, Next gated on a selection, games
  capped at 3 checkboxes, Enter advances, legend focus (`tabindex="-1"` in
  `_step.html.erb`); form submits normally. PC Finder links wired: mega-menu
  promo (`NavigationMenu#promos` → `pc_finder_path(locale:)`) and home banner
  CTA → `pc_finder_path`.

## Code map (Phase 1b-ii-c — PC Finder step 6: controller tests — DONE)

- `test/controllers/pc_finders_controller_test.rb` (13 tests; Games and
  gaming-PC listings created per test, no global listing fixtures): quiz
  render without params (7 `data-quiz-target="step"` fieldsets, game tiles,
  gamer-type tiles, no results block), results (matching listing shown,
  below-required-score listing hidden, estimated FPS per game), invalid
  params (`resolution=8k`/`fps=999`/`games[]=unknown`/`budget=foo`) fall
  back to the quiz, `step=3` → `data-quiz-step-value`, `page=2` pagination
  (25 equal-score PCs, budget keeps the setup builds out of the page), all
  6 locales render without "translation missing" (quiz + results), mega-menu
  promo and home banner CTA link to `/pc-finder`.
- **PC Finder (steps 1–6) is done.** Remaining follow-ups are in Open items.

## Code map (Phase 2 step 1 — follows + reviews data model)

- `db/migrate/2026111918000{1,2}_*.rb` — `follows` (unique
  [follower_id, store_id]) and `reviews` (rating smallint + check constraint
  1..5, status string published/hidden, verified_purchase, unique partial
  [author_id, order_id] WHERE order_id IS NOT NULL, [store_id, status,
  created_at DESC]; `order_id` has **no FK yet** — orders land in Phase 5).
- `app/models/follow.rb` — counter_cache `:followers_count`, self-follow +
  duplicate rejected. `app/models/review.rb` — string enum status, rating
  1..5, title ≤120 / body ≤2000, self-review rejected, `published`/`recent`
  scopes, after_commit → `Stores::RatingRecalculator` (single aggregate
  `pick` → `update_columns(rating_avg, ratings_count)`; guards destroyed
  stores). Error messages under `activerecord.errors.models.*` in 6 locales.
- User: `follows` (foreign_key `follower_id`) / `followed_stores` /
  `reviews_written` + `following?(store)`; Store: `follows` / `followers` /
  `reviews` (dependent destroy).
- Gotcha: `after_commit` never fires under transactional fixtures (Rails
  8.1 included) — `test/services/stores/rating_recalculator_test.rb` runs
  `use_transactional_tests = false` + `Review.delete_all` teardown (fixtures
  reload only clears fixture tables). `t.smallint` doesn't exist — use
  `t.integer limit: 2`.

## Code map (Phase 2 step 2a — shipping addresses)

- `db/migrate/20261119180003_create_addresses.rb` — user/country FKs +
  address fields + `default_shipping`; partial unique index
  `[user_id] WHERE (default_shipping)` needs an explicit `name:` (collides
  with the `t.references` FK index otherwise).
- `app/models/address.rb` — Spain-only rules (province ∈
  `SpanishProvince.codes`, postal `/\A\d{5}\z/` starting with the province
  INE code — no mapping exists on `SpanishProvince` itself), country must be
  `Country.enabled`, `province` nulled for non-ES; first address
  auto-defaults, `before_save :unset_other_defaults` + `make_default!` keep
  the partial unique index safe; `defaults_first` scope, `formatted_lines`.
  User: `has_many :addresses` + `has_one :default_address` (scoped).
- Routes: `resources :addresses, except: :show` + nested
  `resource :default, only: :update, controller: "address_defaults"` (PATCH
  `/account/addresses/:id/default`) inside the locale `:account` namespace.
- `Account::AddressesController` / `Account::AddressDefaultsController` —
  all lookups via `current_user.addresses.find` (foreign record → 404),
  422 re-render on invalid, lazy `t(".success")` flashes. Views
  `app/views/account/addresses/{index,new,edit,_form}`.
- Gotcha: Warden test-mode `sign_in` only covers the *next* request; a 404
  rendered by the exceptions app doesn't set the session cookie, so the next
  request is anonymous — the controller-test setup warms the session with a
  successful GET. `assert_match` fails on translated text containing `'`
  (HTML `&#39;`) — use `assert_select text:`.

## Code map (Phase 2 step 2b — account settings area)

- `db/migrate/20261119180004_add_notification_settings_to_users.rb` — users
  `notification_preferences` jsonb (not null, `{}`), `marketing_opt_in`
  boolean, `marketing_opt_in_at` datetime.
- `User`: `NOTIFICATION_KEYS` / `TRANSACTIONAL_NOTIFICATION_KEYS`,
  `notify?(key, channel = :email)` (per-channel map → flat map → default;
  transactional keys default on), `omniauth_only?`, avatar content-type/≤5 MB
  validation, `notification_preferences` shape validation,
  `sync_marketing_opt_in_at` before_save.
- Routes (`namespace :account`): singular `resource :profile/:password/
  :notifications, only: %i[edit update]`. `Account::ProfilesController`
  (`update_without_password` → email change = confirmable reconfirmation;
  email field/param only when not omniauth-only), `Account::PasswordsController`
  (`update_with_password` + `bypass_sign_in`), `Account::NotificationsController`
  (checkbox map → real booleans via `ActiveModel::Type::Boolean`).
- Account frame: `app/views/account/_sidebar.html.erb` (active item from
  controller_name; mobile = horizontal scroll tabs) + `_shell.html.erb`
  rendering `yield :account_body` — pages wrap content in
  `content_for :account_body` because a `render do` block would evaluate lazy
  `t(".key")` against the shell partial's virtual path. Addresses views use
  the same frame.
- Gotchas: `Hash#dig(key, channel)` raises on plain-boolean values; Devise's
  session salt derives from `encrypted_password` (clearing it invalidates the
  session — re-`sign_in` in tests); `f.check_box "a[b]"` nests names wrongly
  → `check_box_tag`; YAML plain scalars can't contain `": "` (quote those
  strings).

## Code map (Phase 2 step 3 — seller store settings)

- Routes: `namespace :seller { resource :store, only: %i[new create edit
  update] }` (locale scope). Singular — one store per user, no id in the URL,
  other sellers' stores unreachable by construction.
- `Seller::StoresController` — authenticate_user!; new/create = "open your
  store" (redirect to edit once a store exists), edit/update redirect to new
  while there is none. All writes via `Store#assign_settings` (consumes
  virtual `remove_logo`/`remove_banner` flags, purges attachments) — skinny
  controller.
- `app/validators/spanish_tax_id_validator.rb` — NIF/NIE mod-23 check letter
  (TRWAGMYFPDXBNJZSQVHLCKE), CIF format-only (type letter + 7 digits + digit
  or A–J control). Blank passes (presence is business-only).
- Store: name 2..60 + case-insensitive uniqueness; vacation_message ≤280;
  logo/banner png/jpeg/webp ≤5/8 MB; `normalize_tax_id` before_validation;
  **slug regenerates on rename** (`should_generate_new_friendly_id?`) —
  `:history` added in step 4, so old store URLs keep resolving (301, see
  below).
- Views `seller/stores/{new,edit,_form}` use the account shell; business
  fields toggle via CSS `:has` (`.store-form:has(#store_kind_business:checked)
  .business-fields` in application.css — no JS, CSP-safe). Sidebar gained
  "My store" (edit/new per `current_user.store`).
- Gotchas: 422 re-render previews must check `attachment&.persisted?` (a
  rejected upload is attached in memory → variant pipeline raises); Devise
  confirmable rejects `sign_in` for unconfirmed users (`:pending` fixture
  can't sign in — create a confirmed user in tests).

## Code map (Phase 2 step 4 — store slug history, follow button + reviews tab)

- Store: `friendly_id :slug_source, use: %i[slugged history]`;
  `find_by_param` falls back to `FriendlyId::Slug` (latest row, scoped by
  `sluggable_type`) so renamed stores keep resolving; `StoresController#show`
  301s (`:moved_permanently`) stale slugs to the canonical `store_path`.
  `Store#rating_distribution` — published reviews grouped by rating,
  `{ 5 => n, …, 1 => 0 }` in 5→1 order (reviews tab bars).
- Route `resource :follow, only: %i[create destroy], controller:
  "stores/follows"` nested under stores → `POST/DELETE /s/:store_slug/follow`
  (singular — one follow per user+store). `Stores::FollowsController`
  (authenticate_user!, `set_store` via `find_by_param`): create via
  `current_user.follows.new` (self-follow fails validation → button
  re-renders unchanged), destroy `find_by(store)&.destroy`; turbo_stream
  renders `stores/follows/follow_state.turbo_stream.erb` (replaces
  `dom_id(store, :follow)` + `dom_id(store, :followers_count)`; `@store.reload`
  first — counter cache updates in SQL); HTML fallbacks `redirect_back` +
  flash.
- Partials: `stores/_follow_button` (hidden on own store, sign-in link for
  anonymous, `compact:` variant for the listing seller box — `?compact=1`
  rides the form so the stream re-applies styling), `stores/_followers_count`
  (header stat wrapper), `stores/_review` (author, stars, verified-purchase
  badge, seller reply). `StoresHelper#review_stars`; `star` icon in
  `IconHelper`.
- Reviews tab: `StoresController#load_reviews` — `reviews.published.recent`
  + avatar preload + manual `Pagy::Offset` (`REVIEWS_PER_PAGE = 10`);
  `stores/show` reviews section = avg + stars + distribution bars + cards +
  `browse/pagination` reuse.
- Demo seed: 3–12 follows + 3–8 published reviews per store (skewed ratings,
  ~70% verified, ~35% seller replies, backdated via `update_columns`) — runs
  after the random counter columns so counters/recalculator win.
- Gotchas: fixtures bypass FriendlyId (history assertions need a
  model-created store); Devise 5 treats turbo_stream as navigational →
  unauthenticated follow POSTs 302 to sign-in, not 401.

## Code map (Phase 2 step 5 — header account menu)

- `shared/_account_menu` (rendered by `shared/_header` in place of the old
  account-icon placeholder): signed out → Sign in + Sign up (`nav.sign_up`,
  sign up gated on `AppSettings.enabled?(:registrations_enabled)`, which
  defaults to off); signed in → avatar button (attached-image check +
  `User::AVATAR_SIZES[:thumb]` `resize_to_fill` variant, initials-circle
  fallback) + name/email header + `shared/_account_links`, inside the
  existing `dropdown` Stimulus controller.
- `shared/_account_links` (single source for header dropdown **and** mobile
  drawer; `variant:` local only tweaks the sign-out button class): Buying
  (My orders TODO Phase 5, Messages & offers + Wishlist TODO Phase 6 — all
  `#` placeholders rendered as `aria-disabled` spans with a "Soon" pill,
  never dead links — plus Account settings → `edit_account_profile_path`);
  My store (owner: Public profile → `store_path`, Seller dashboard + My
  listings soon (Phase 4), Store settings → `edit_seller_store_path`; else
  Open your store → `new_seller_store_path`); Admin panel soon (Phase 7)
  for `admin?`/`moderator?` only; sign-out `button_to`.
- Gotcha: the owner branch checks `current_user.store&.persisted?` — the
  seller form builds an unsaved store on `current_user`, so a bare truthy
  check crashes `store_path` (nil slug) while rendering the header.
- `dropdown_controller.js`: gained ArrowUp/ArrowDown roving focus (wraps at
  both ends) on top of click toggle / outside-click + Esc close /
  aria-expanded / focus-first-item; placeholders are spans so keyboard
  focus skips them naturally.
- I18n: `account_menu.*` (14 keys) + `nav.sign_up` in all 6 locales.
- Tests: `test/integration/header_account_menu_test.rb` (9). Header + drawer
  are both in the DOM, so negative assertions must hold across both copies.

## Code map (Phase 2 step 6 — GDPR account deletion + data export)

- Routes (`namespace :account`): singular `resource :data_export, only:
  %i[show create]` + `resource :deletion, only: %i[show destroy]`.
- **Export**: `Accounts::DataExporter` builds the JSON (profile, addresses,
  notification prefs, store + its listings, follows, reviews written),
  attaches `User#data_export` (`has_one_attached`) and stamps
  `data_export_generated_at`; `Account::DataExportJob` runs it async. Show
  page: request `button_to` + `rails_blob_path(disposition: "attachment")`
  download link once ready. Throttle once per 24h
  (`User::EXPORT_THROTTLE` / `#data_export_throttled?`), checked in the
  controller before enqueueing (flash alert otherwise). Email notification
  TODO Phase 6.
- **Deletion**: not Devise registration#destroy (would orphan reviews).
  Show = warning page + confirmation challenge (current password; username
  for `omniauth_only?` accounts, `secure_compare`); wrong/blank → 422.
  `Accounts::Deleter` transaction: AASM `archive!` listings, store
  `vacation_mode: true` (unpublishes — public scopes exclude vacation
  stores), destroy addresses, anonymize in place (email →
  `deleted-<id>@deleted.invalid` via `skip_reconfirmation!`, username →
  `deleted_user_<id>` — hyphens fail the username format validation —,
  names/phone/unconfirmed_email nil, prefs `{}`, marketing off, avatar +
  data_export purged), stamp `deleted_at`. Reviews kept; `stores/_review`
  shows `stores.review.deleted_user` for `author.deleted?`.
- `User#active_for_authentication?` false when deleted (blocks sign-in form
  **and** remember-me); `inactive_message` → `:deleted` →
  `devise.failure.deleted` (devise-i18n merges the extra key).
- Sidebar: "Download my data" item; "Delete account" → `account_deletion_path`.
- Gotcha: `ActiveStorage::Blob#download` returns ASCII-8BIT — `force_encoding
  ("UTF-8")` before comparing non-ASCII JSON in tests.

## Code map (Phase 3 step 1 — seller listings CRUD)

- Routes: `namespace :seller { resources :listings, only: %i[index new
  create edit update destroy] }`. Header + mobile drawer "List an item"
  buttons now point at `new_seller_listing_path` (were `root_path`).
- `Seller::ListingsController`: everything scoped to `current_user.store`
  (foreign listings 404 via `render_not_found`, which moved from
  `Browseable` up to `ApplicationController`). `new`/`create` lazily create
  the store via `Stores::EnsureForUser` so the header button never
  dead-ends. `new` builds a draft prefilled from store settings
  (`allow_offers_default`, province/city/postal_code). create/update only
  ever save — published listings edited here go back to pending_review
  through the model's own `return_to_review_if_content_edited`. destroy:
  hard delete when `Listing#deletable?` (draft/rejected, never went
  public), otherwise AASM `archive!`.
- `Listing` additions: `TITLE_MIN/MAX_LENGTH` constants (form reads the
  max), `Listing.status_counts(store)` (one grouped query, 0-filled for
  the index tabs), `#deletable?`, and virtual euro writers/readers
  `#price`/`#original_price`/`#shipping_price` (`Listing.euros_to_cents`:
  blank/garbage → nil so validations surface it; blank shipping → 0 since
  the column is NOT NULL). Fresh records render zero-cent defaults as
  blank inputs.
- Views: new `seller/_shell` + `seller/_sidebar` (Dashboard "Soon" pill
  until Phase 4, My listings, Store settings) — `seller/stores/{new,edit}`
  switched from the account shell to it. `seller/listings/{index,new,edit,
  _form}`: index has one tab per status with counts + rejection reason on
  rejected rows; form has category grouped select
  (`Seller::ListingsHelper#grouped_category_options`, active leaves grouped
  by translated parent name), title with `char-count` Stimulus counter,
  condition radio cards with short descriptions, euro price fields,
  shipping/location/offers sections, and clearly marked Photos (step 3)
  placeholder (the Specifications placeholder became the real specs frame in
  step 2). `form_with` needs an explicit `url:` — there is no top-level
  listings route.
- i18n: `seller.listings.*`, `seller.sidebar.*`, condition short
  descriptions, and full `activerecord.attributes.listing` label set in
  all 6 locales.

## Code map (Phase 3 step 2 — sell-form specification fields)

- Routes: `namespace :seller { resource :listing_spec_fields, only: :show }`
  — Turbo Frame endpoint `GET /seller/listing_spec_fields?category_id=…
  [&listing_id=…]`.
- `Seller::ListingSpecFieldsController`: auth required, `layout false`,
  renders only the `listing_specs` frame; `category_id` resolved via
  `Category.active`, optional `listing_id` looked up in `current_user.store`
  (foreign ids 404 so another seller's specs never leak).
- `seller/listings/_specs_fields.html.erb` (shared by the form and the
  endpoint): every inherited `FilterDefinition` with `show_in_listing_form`
  via `Category#effective_filter_definitions`, grouped by translated group,
  options featured-first. multi_select → checkbox chips
  (`listing[specs][key][]`), single_select → select, boolean → hidden
  "false" + checkbox "true" (scalar names), range → number input + unit.
  `required_in_form` fields get a `*` + note. NOTE: option lists must start
  from `FilterOption.featured_first.where(...)` — chaining `featured_first`
  onto the `has_many` (default-scoped `ordered`) merges orders and the
  association's `position, id` wins.
- `frame_src_controller.js` (Stimulus, on the category+specs wrapper):
  `change->frame-src#refresh` points the frame's `src` at the endpoint with
  the chosen `category_id` (+ `listing_id` when editing); blank category
  clears the frame without a request. The frame is server-rendered on
  new/edit when the listing has a category.
- `Listing.sanitize_specs(category, raw)`: sell-form whitelist — keeps only
  the category's form-visible definitions, drops unknown keys/values, maps
  "1"/"0" → "true"/"false", keeps range values as typed. Called from
  `Seller::ListingsController#listing_params` (`specs: {}` permitted via
  `params.expect`).
- `Listing` required-specs validation: `required_specs_present` runs when
  `will_save_change_to_status?` and the new status is pending_review or
  published (so AASM `submit!` enforces it; drafts stay incomplete). Error
  key `errors.messages.missing_required_spec`.

## Code map (Phase 3 step 3 — listing photos)

- `listings.image_order` jsonb (default `[]`) — seller gallery order, an array
  of attachment-id strings (blob signed ids also resolve).
- `Listing` gallery API (`# --- Gallery ---`): `images=` **appends** (rebuilds
  the `CreateMany` change from `images.blobs + attachables`, preserving
  `pending_uploads`) because the sell form only submits newly picked files;
  `remove_image_ids=` accepts attachment ids or blob signed ids (string-
  normalized), purges only this listing's matches via `purge_later` (rows go
  away synchronously), resets `images_attachments`/`images_blobs` caches and
  rebuilds a pending append so purged blobs aren't re-attached; `image_order=`
  parses JSON string or array; `ordered_images` sorts by image_order with
  unordered images falling back to attachment order at the end (first = cover).
  `snapshot_review_context` uses `@images_before_edit ||=` — `remove_image_ids=`
  snapshots before purging so the re-review diff still sees the old gallery.
- Cover order flows through `ListingsHelper#listing_picture` and
  `listings/_gallery.html.erb` (both use `ordered_images`).
- Direct uploads: importmap pin `@rails/activestorage` → `activestorage.esm.js`,
  `startActiveStorage()` in `application.js`.
- `seller/listings/_form.html.erb` Photos section: `listing[images][]` file
  input (multiple, `direct_upload: true`), `ordered_images` tiles (thumb
  variant) with move buttons + draggable grip + `listing[remove_image_ids][]`
  checkbox + Cover badge on the first, hidden `listing[image_order]` (JSON),
  "N / max" counter (`AppSettings max_images_per_listing`) and tips. Tiles for
  pending (failed-save) or non-`variable?` blobs render a filename placeholder
  — unsaved blobs have no signed id and text blobs can't be transformed.
- `image_uploader_controller.js` (Stimulus): object-URL previews (revoked on
  disconnect), own `pendingFiles` list rebuilt into `input.files` via
  `DataTransfer` (the browser replaces the FileList on every pick),
  `direct-upload:initialize/progress/error/end` progress bars, drag-and-drop +
  arrow-button reordering, keeps hidden order + Cover badge + counter/warning
  in sync. New files have no attachment id → never in image_order (server
  appends them).
- `IconHelper` gained the `grip` icon; i18n keys `form.photos_*` +
  `form.photos_tips.*` in all 6 locales (`photos_placeholder` removed).

## Code map (Phase 3 step 4 — seller listing lifecycle)

- Routes: singular nested resources under `seller/resources :listings` —
  `resource :submission, only: :create` / `resource :pause, only: %i[create
  destroy]` (create = pause, destroy = resume) / `resource :sale, only:
  :create`, all `controller: "listings/<plural>"`.
- `Seller::Listings::BaseController`: `set_listing` via
  `current_user.store.listings.find_by_param` + ownership re-check (the
  FriendlyId history fallback escapes store scope); `rescue_from
  AASM::InvalidTransition` → alert; `render_row`/`render_row_alert` =
  turbo_stream (`seller/listings/row_update` replaces `dom_id(listing)` +
  the `toasts` area, flash.now) or HTML redirect.
- `Listings::Submitter` service: `may_submit?` guard → Result
  (`invalid_transition?` flag + translated message); `submit!` (bang —
  non-bang never persists) rescued as `ActiveRecord::RecordInvalid` →
  Result with `errors.full_messages`; `approve!` when `listing_auto_approve`.
  SubmissionsController redirects HTML failures to **edit** (validation) or
  **index** (invalid transition). Pauses/Sales controllers are thin
  (`pause!`/`resume!`/`record_offline_sale!`).
- `Listing`: `record_offline_sale!` (decrement or `mark_sold!`), `mark_sold`
  from paused too, `image_present_for_review` validation on
  `entering_review_or_published?`.
- `Seller::ListingsController#update` + form "Save & submit" button
  (top-level `submit_for_review=1` param) run the same Submitter after
  saving. `_row.html.erb` (index row, dom_id turbo target, state-dependent
  action buttons) + `row_update.turbo_stream.erb`; edit.html.erb per-status
  banner (rejection reason, public link when published).
- Tests: `test/controllers/seller/listings/{submissions,pauses,sales}_
  controller_test.rb`; `attach_photo` helper + `publish` now attaches a stub
  photo (submit! requires one). Gotchas: `response.media_type` has no
  charset; top-level params must be merged outside the `listing:` hash.

## Code map (Phase 3 step 5 — seller dashboard)

- Route `resource :dashboard, only: :show` in `namespace :seller` →
  `Seller::DashboardsController#show` (authenticate_user!; no store →
  `new_seller_store_path`). Builds `Seller::Dashboard.new(store, period:)`.
- `app/services/seller/dashboard.rb` PORO: `PERIODS` allowlist (7d/30d/90d,
  default 30d — unknown params silently fall back, same pattern as the
  listings index status param). KPIs: `Listing.status_counts` (one grouped
  query) for published/pending, `SUM(views_count)`/`SUM(favorites_count)`,
  denormalized `followers_count`/`rating_avg`/`ratings_count`, sold count +
  revenue (`sold_at` in period, single COUNT+SUM — **revenue is provisional:
  sum of sold listings' `price_cents`, TODO Phase 5 order totals**).
  `sold_per_day` = zero-filled `[Date, count]` series
  (`group("sold_at::date")`). Needs attention (capped at 5 each): rejected
  (with `rejection_reason`), drafts untouched >7 days (`updated_at`),
  photo-less live-ish listings via `where.missing(:images_attachments)`
  (the `has_many_attached` association is a real association). Top 5 by
  `views_count`; activity = 10 latest `updated_at` (every lifecycle event
  bumps it). Onboarding checklist (logo attached / bio present / first
  listing / `published_at NOT NULL`), shown when the store has no listings.
  Every panel is one aggregate query, memoized per instance.
- `seller/dashboards/show.html.erb` (seller shell): greeting, period
  switcher links (aria-current), KPI card grid, **pure-CSS bar sparkline**
  (bar height = day's share of the busiest day, inline `style`, no JS),
  attention panel (only non-empty lists; Fix → edit), top-listings table,
  activity feed with status pills, quick actions (List an item / Store
  settings / View public store), onboarding checklist card.
- Links wired: sidebar Dashboard (Soon pill gone — sections array now
  `dashboards/listings/stores`, active via `controller_name`), account
  dropdown "Seller dashboard" + "My listings" (Soon gone). Listing
  submission redirects unchanged.
- Gotchas: backdate `sold_at`/`updated_at` with `update_columns` in tests
  (callbacks bump `updated_at`); the header still has Soon pills (orders/
  messages/wishlist/admin), so sidebar assertions must scope to
  `nav[aria-label='Seller area']`.

## Code map (Phase 3 step 6 — selling landing pages)

- **Phase 3 is complete** (steps 1–6: sell CRUD, spec fields, photos,
  lifecycle, dashboard, selling landing pages).
- Route `resource :selling, only: :show, path: "sell"` (locale scope) →
  `SellingsController#show`: `expires_in 1.hour, public: true` for
  anonymous users; whole body in one fragment cache keyed on locale +
  `commission_enabled`/`commission_percent`/`payments_enabled` +
  `SellingPage#data_version` (max updated_at of Listing/Store, cached 5 min)
  so flag flips and new data bust it.
- `app/services/selling_page.rb` (HomePage pattern — cached id lists +
  `in_order_of` reload): `featured_stores` via new `Store.featured` scope
  (not on vacation, `sales_count >= 1`, sales → rating → id desc, limit 5)
  and `recently_sold` (sold within 1 month, limit 14).
- `sellings/show.html.erb`: hero + final CTA → `new_seller_listing_path`;
  3 steps and payout FAQ answer switch copy on `payments_enabled`
  (escrow vs pay-on-delivery/chat); fee perk/FAQ switch on
  `commission_enabled` ("0% commission during launch" vs "%{percent}%");
  featured-stores grid (logo variant or `store_initials` monogram from
  `StoresHelper`, verified badge, pluralized sales count — hidden when
  empty); 6-question FAQ as native `<details>`; recently-sold strip reuses
  `listings/_scroller` (self-hides when empty).
- `SellToUsController#require_flag` uses `render_not_found` (404) when
  `sell_to_us_enabled` is off; `sell_to_us/show.html.erb` is a full info
  page (hero, static I18n payouts table, 4 steps, `<details>` FAQ) with a
  **mailto CTA** to `AppSettings.get(:support_email)` — no offer flow yet.
- Entry points: footer "Sell on PCMarket" + home `sell_cta.primary`
  "Start selling" both → `selling_path` (placeholders replaced); header/
  drawer/mega-menu sell-to-us links stay flag-gated.
- Gotchas: unquoted YAML scalars break on `: ` (and fr ` : `) — use em
  dashes; `assert_select` CTA counts must use `minimum:` because header/
  footer add their own sell links.

## Code map (Phase 4 step 1 — cart)

- Routes (locale scope): `resource :cart, only: :show` + `resources
  :cart_items, only: %i[create update destroy]` — singular cart (one per
  visitor/user, no id in the URL); cart items addressed by row id. Both
  controllers `require_checkout_enabled` → **404 while the flag is off**,
  and the header cart link + listing-page CTAs hide with it.
- `db/migrate/2026112015000{1,2}_*.rb`: `carts` (nullable `user_id` FK —
  guest carts keep NULL and are addressed by `token`; unique partial index
  on user_id WHERE NOT NULL = one cart per user; unique token) and
  `cart_items` (unique [cart_id, listing_id] doubling as the cart FK index,
  `quantity > 0` check constraint, `unit_price_cents` price snapshot).
- `Cart` (`app/models/cart.rb`): `COOKIE = "pcmarket_cart"`, `AddOutcome`
  struct (`:added/:increased/:capped` success; `:own_listing/
  :not_available` rejected), `#add` (visibility + own-listing guards, stock
  cap, price snapshot), `#items_by_store` (multi-seller groups),
  `#subtotal_cents`/`#shipping_cents` (one fee per distinct listing)/
  `#count`, `#refresh!` (drops invisible listings, syncs price/stock drift,
  returns translated notices for the cart page), `#merge!` (guest → user,
  re-runs `#add` so all rules apply, destroys source). `CartItem`:
  quantity/price validations + unique [cart_id, listing_id].
  User `has_one :cart`, Listing `has_many :cart_items` (both dependent
  destroy).
- `CurrentCart` concern: `current_cart` (signed-in → lazy
  `current_user.create_cart!`; guest → `Cart.guest.find_by(token:)` from
  the cookie, **nil without one — no cart row per visitor**),
  `cart_for_adding` (creates guest cart + cookie, only from add actions),
  `require_checkout_enabled`. Cookie: `cookies.signed.permanent` **with
  explicit `httponly: true`** (Rails 8.1 does NOT default httponly —
  verified via Set-Cookie probe; same as LocaleConcern).
  `Current.cart` mirrors the resolved cart so the badge reuses it.
- `config/initializers/warden_cart_merge.rb`: Warden `after_set_user`
  (scope `:user`, only `authentication`/`set_user` — session restores
  (`:fetch`) don't re-merge) reads the cookie from
  `ActionDispatch::Request.new(auth.env).cookie_jar` (the jar lives in the
  env header `action_dispatch.cookies`, so it IS the one the middleware
  commits) and `user_cart.merge!(guest_cart)` + deletes the cookie. Rails
  8.1 signed cookies have **no `_` prefix** (signature in the value), so
  plain `cookies.delete(Cart::COOKIE)` removes the right cookie.
- `CartsController#show` (refresh! + notices + groups) /
  `CartItemsController` (create = add w/ `buy_now=1` redirect-to-cart
  placeholder; update caps at stock; destroy; all scoped via
  `current_cart&.cart_items` → foreign ids 404). Turbo gets
  `cart_items/cart_update.turbo_stream.erb` (replaces `#cart_count` +
  `#toasts`); HTML falls back to `redirect_back_or_to cart_path` + flash.
- UI: header cart link + `shared/_cart_count` badge (`#cart_count`,
  hidden at 0, "99+" cap, `CartHelper#cart_badge_count` — no DB query for
  cookieless guests); `listings/show` Buy-now/Add-to-cart `button_to`s
  (`cartable` = flag + `visible_to_public?` + not own listing);
  `carts/show` store-grouped cards, quantity select + remove, per-store +
  summary totals, checkout CTA = `aria-disabled` "Soon" span (TODO Phase 4
  step 3). `IconHelper` gained `trash`. i18n: `carts.*`, `cart_items.*`,
  `nav.cart` in all 6 locales.
- Gotchas: `assert_includes response.body` fails on translated text with
  `"`/`'` (escaped `&quot;`/`&#39;`) — use `assert_select text:`; the
  Warden hook never runs under the test-mode `sign_in` helper, so merge
  tests POST to `/users/sign_in` for real; guest carts have `user_id` nil
  so the own-listing guard can't fire until the merge re-adds as the user.

## Code map (Phase 4 step 2 — orders data model + placement)

- `db/migrate/2026112016000{1,2}_*.rb`: `orders` (unique `number`
  "PCM-YYMM-XXXXXX", nullable `buyer_id`→users for guest checkout +
  NOT NULL `buyer_email`, money in cents with non-negative check
  constraints, jsonb `shipping_address`/`billing_address` snapshots,
  lifecycle timestamps incl. `auto_complete_at`, stripe ids,
  `checkout_group`, indexes [store_id,status,placed_at desc] and
  [buyer_id,placed_at desc]) and `order_items` (listing FK nullifies on
  delete; title/price/condition/image snapshots + `sold_listing` flag,
  check constraints).
- `Order` (`app/models/order.rb`): AASM
  pending→paid→shipped→delivered→completed + cancelled (pending/paid),
  refunded (paid/shipped/delivered/disputed), disputed (shipped/delivered)
  ⇄ resolve. **AASM 6 gotchas**: transition callbacks go on the `event`
  (`before:`), NOT on `transitions` (silently ignored); a positional
  event arg matching a to-state name is consumed as the target state →
  `resolve_dispute!(outcome: "refunded"|"completed")` takes a hash;
  `aasm.from_state` is unset in event-level before callbacks → restock
  pre-shipment check uses `status_in_database`. `ship!` requires
  tracking_number unless `shipping_method == "pickup"`.
  `confirm_delivery!` sets `auto_complete_at = delivered_at +
  Order.auto_complete_days` (Setting `buyer_protection_days`, not seeded;
  constant 2). `can_be_cancelled_by?` = buyer && may_cancel?.
- `Listing` gained `relist` (sold→published) for restock; `Order#restock_listings`
  relists `sold_listing` items and adds quantity back for the rest
  (skips deleted listings).
- `Orders::Placer` (`app/services/orders/placer.rb`):
  `call(cart:, buyer:, email:, shipping_address:, shipping_method:,
  payment_method:, discount_code: nil)` → `Result(orders, errors,
  checkout_group)` with `success?`. One transaction; listings locked FOR
  UPDATE ordered by id; abort (via `Rollback < ActiveRecord::Rollback`)
  on invalid input / empty cart / missing listing / not visible / short
  stock / `cart.refresh!` notices. One Order per store sharing a uuid
  checkout_group; commission snapshotted from AppSettings; shipping per
  distinct listing (pickup/free → 0); clears purchased cart rows.
  `discount_code` ignored (TODO step 7).
- i18n: `orders.placer.errors.*`, `activerecord.attributes.order.{statuses,
  payment_statuses}.*`, order `tracking_number.required_for_shipping` in
  all 6 locales.
- Tests: `test/models/order_test.rb` (21), `test/services/orders/placer_test.rb`
  (19). Model tests must pre-decrement listing quantity to simulate
  placement before asserting restock.

## Testing

- `bin/rails test` — **535 tests green**: all Phase 0 checks plus model
  validations, AASM transitions (incl. edit-returns-to-review and
  auto-approve), search (accents, spec AND/OR, price/condition filters,
  sorts, facets, N+1, category descendants), seeds idempotency (twice +
  admin-edit survival), i18n parity; Phase 1b-i adds category browse
  (filters/sort/pagination/pills/404s), search page, listing show
  (etag/304, preview gating, 301 old slugs, scrollers), views-counter job
  and Listing browse-method tests; Phase 1b-ii-a adds home (empty +
  populated, en/es), mega-menu links + sell-to-us promo flag gating,
  NavigationMenu service (items, chipset hrefs, cache stamp), store show
  (own listings only + sold-last, about/reviews tabs, vacation banner,
  404) and a test that `DEMO=1` seed data never loads outside development.
  PC Finder step 2 adds no new tests — the new seeds are covered by the
  idempotency test (its `>=` counts still hold); step 3 adds
  `test/services/pc_finder/{query,recommender}_test.rb` (28 tests, records
  created per test); step 6 adds
  `test/controllers/pc_finders_controller_test.rb` (13 tests); Phase 2 step 1
  adds `test/models/{follow,review}_test.rb` and
  `test/services/stores/rating_recalculator_test.rb` (15 tests, users/reviews
  created per test); Phase 2 step 2a adds `test/models/address_test.rb` and
  `test/controllers/account/addresses_controller_test.rb` (30 tests — ES
  postal/province rules, default-address logic, auth, ownership 404s, 422
  re-render, PATCH default); step 2b adds
  `test/controllers/account/{profiles,passwords,notifications}_controller_test.rb`
  + `notify?`/avatar/marketing tests in `test/models/user_test.rb` (26 tests —
  auth, 422s, wrong current password, reconfirmation, avatar accept/reject,
  prefs persisted, marketing timestamp); step 3 adds
  `test/validators/spanish_tax_id_validator_test.rb` +
  `test/controllers/seller/stores_controller_test.rb` (30 tests — NIF/NIE/CIF
  accept/reject, auth, open-store-once, 422s for short/taken name, missing
  business identity and bad tax id, vacation toggle, logo/banner
  attach/reject/remove, ownership) and flips the store slug test to
  rename-regenerates; step 4 adds
  `test/controllers/stores/follows_controller_test.rb` (14 tests — auth HTML +
  turbo, turbo_stream button/count swaps, self-follow, HTML fallbacks, 404)
  plus stores_controller 301/reviews-tab tests and a FriendlyId-history
  store test; step 5 adds `test/integration/header_account_menu_test.rb`
  (9); step 6 adds `test/services/accounts/{data_exporter,deleter}_test.rb`
  + `test/controllers/account/{data_exports,deletions}_controller_test.rb`
  + deleted/throttle user-model tests (29 tests — export JSON shape, throttle
  flash + disabled button, download link, 422 wrong password, sign-out +
  root redirect, deleted user refused at sign_in); Phase 3 step 1 adds
  `test/controllers/seller/listings_controller_test.rb` (20 tests — auth,
  store auto-creation on new/create, euro→cents create, 422s incl. garbage
  price, edit/update own listing, published edit returns to review, foreign
  listing 404 on edit/patch/delete, draft/rejected hard delete vs published
  archive, index status filter + counts + rejection reason + bogus-status
  fallback); Phase 3 step 2 adds
  `test/controllers/seller/listing_spec_fields_controller_test.rb` (6 tests —
  auth, inherited definitions rendered, featured-first options, prompt
  without category, own-listing values prefilled, foreign listing 404), two
  specs create/update tests in the listings controller test (stored +
  unknown keys/values dropped, boolean "1" → "true") and two `Listing`
  tests (`.sanitize_specs` whitelist, required spec enforced on `submit!`
  but not on drafts); Phase 3 step 3 adds 7 photos tests to the listings
  controller test (create attaches uploads, second update appends, image_order
  persisted + ordered_images respects it, remove_image_ids removes only the
  chosen one, foreign attachment id ignored, exceeding max_images_per_listing
  → 422, non-image upload → 422) and 5 to the listing model test
  (`ordered_images` follows image_order, appends missing ids at the end,
  `remove_image_ids` purges only the match, image change on a published
  listing returns it to pending_review, auto-approve keeps it published);
  Phase 3 step 4 adds
  `test/controllers/seller/listings/{submissions,pauses,sales}_controller_test.rb`
  (23 tests — submit draft/rejected, missing photos/specs alerts + edit
  redirect, invalid transition → index redirect, auto-approve publishes,
  turbo row+toasts stream, ownership 404, auth; pause/resume round-trip +
  invalid-state alerts; sale sold/decrement/invalid-state; HTML fallbacks)
  plus Save & submit + status-banner tests in the listings controller test
  and `record_offline_sale!`/paused→sold/submit-needs-photo model tests;
  Phase 3 step 5 adds `test/services/seller/dashboard_test.rb` (13 tests —
  period sanitizing, KPI counts/sums, period-filtered sold+revenue,
  zero-filled sold-per-day, attention lists, top/activity caps, onboarding
  checklist progression, memoization) and
  `test/controllers/seller/dashboards_controller_test.rb` (7 tests — auth,
  no-store redirect, KPI render, onboarding vs panels, chart+attention
  render, period param sanitized, sidebar link), and the header menu test
  now asserts the Seller dashboard / My listings links; Phase 3 step 6 adds
  `test/controllers/sellings_controller_test.rb` (16 tests — 6-locale render
  without missing translations, public 1h cache headers, sell CTAs, fee copy
  both commission states, payout copy both payments states, featured stores
  and recently-sold render/hide, home+footer links to /sell) and
  `test/controllers/sell_to_us_controller_test.rb` (7 tests — flag on/off/
  missing 404s, 6-locale render, mailto CTA, sell-to-us links hidden when
  off / shown when on; the 3 original tests moved out of
  `pages_controller_test.rb`); Phase 4 step 1 adds
  `test/models/{cart,cart_item}_test.rb` +
  `test/controllers/{carts,cart_items,cart_sign_in_merge}_controller_test.rb`
  (~49 tests — add/increase/cap/own-listing/invisible guards, price
  snapshot + refresh! notices, cookie signed+httponly, no cart row for
  cookieless visitors, lazy user cart, update cap + foreign-item 404,
  turbo badge/toasts streams, flag 404s + hidden header link, badge count,
  sign-in merge incl. cookie clearing and own-listing merge-to-nothing).
- Acceptance: `bin/rails db:migrate:redo STEP=12` + `db:migrate` + `db:seed`
  ×2 verified clean.
- Remember `env -u BUNDLE_FORCE_RUBY_PLATFORM` for any bundler/rake command
  run outside `bin/dev`; export `TAILWINDCSS_INSTALL_DIR` (see README
  Troubleshooting) when the tailwind binary isn't found.

## Open items

- PC Finder: admin CRUD for `Game` rows and listing `performance_score`
  pending Phase 7 (admin UI); game tiles show initial-letter placeholders
  until real game images are attached (`Game#image`, nothing seeded).
- Phase 1b-ii+: admin UI
  for categories/filters/labels/settings (seeds cover data now).
- Store follow button + reviews tab (rating distribution, cards, pagination)
  ship (Phase 2 step 4); the store **message** button is still a `#`
  placeholder (Phase 6 messages).
- **Review creation UI pending Phase 5** — reviews can only be written via
  seeds/console; the buyer "leave a review" flow lands with orders (so
  `verified_purchase`/`order_id` can be set honestly).
- **Devise 5 redirects turbo_stream unauthenticated follow posts to sign-in**
  (turbo_stream requests are treated as navigational → 302, not 401). Accepted
  behavior for now (tested); if follow buttons ever move to background/frame
  contexts, revisit with a turbo-aware failure response.
- Reviews `order_id` has no FK yet — the `orders` table now exists
  (Phase 4 step 2), so the FK + `verified_purchase` wiring can land with
  the Phase 5 review UI.
- Mega-menu budget/theme links need ProductLabel/SellerTag rows (seeds ship
  them; a bare fixture catalog silently drops those columns — demo seed
  `DEMO=1 bin/rails db:seed` fills everything).
- Wishlist/offers/chat buttons are `#` placeholders gated by AppSettings
  flags (`payments_enabled`, `offers_enabled`, `chat_enabled`) — Phases 5/6.
  The cart ships (Phase 4 step 1) and the orders model + `Orders::Placer`
  service ship (Phase 4 step 2), but there is **no checkout UI yet** — the
  cart CTA is a "Soon" placeholder until Phase 4 step 3 (checkout
  controller/views calling the Placer), and "Buy now" just redirects
  to the cart. The account menu's orders/messages/wishlist/admin-panel
  items are "Soon" pills until those pages land (Phases 5–7) — swap them
  for real links there.
- Mobile price filter loses values without JS (euro→cents sync is Stimulus).
- CI not set up yet.
- Address book is account-only for now — checkout/sell-flow pickup of
  `User#default_address` lands with Phase 5 (orders).
- Notification preferences are stored but nothing sends them yet — mailer
  wiring per `User#notify?` lands with the features that emit them (orders,
  messages, offers, saved searches). GDPR deletion + data export ship
  (Phase 2 step 6); the export-ready **email notification** is still TODO
  (Phase 6 mailer wiring).
- **Sell-to-us offer flow is mailto-only** (Phase 3 step 6): the page and
  its "Request an offer" button email `support_email` directly; a real
  quote-request form/offer pipeline is a later phase. Payouts table rows are
  static I18n strings, not price data.
- No commit made for Phases 0/1a/1b-i/1b-ii/2.1/2.2a/2.2b/2.3/2.4/2.5/2.6/
  3.1/3.2/3.3/3.4/3.5/3.6/4.1 — awaiting user review.
