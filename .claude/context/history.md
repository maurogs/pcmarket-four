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

## 2026-11-19 — Phase 1b-i: category browse, search UI & listing page (uncommitted)

Storefront layer on the 1a model/service stack. Category pages
(`/c/:slug`) and `/searches` share a Browseable concern + `app/views/browse/`
partials (facet sidebar: condition/labels/seller_tags/specs + euro price
inputs synced to cents by the `filters` Stimulus controller; active-filter
pills; styled Pagy pagination; results in a `browse_results` Turbo frame;
mobile filter drawer). Listing cards use a webp `<picture>` helper with
per-request FilterDefinition memos (no N+1). `ListingsController#show`:
gallery, spec table grouped by FilterDefinition group, shipping/estimated
arrival, protection + AppSettings-gated CTA placeholders, similar/more-from-
seller scrollers (ids cached 10 min), FriendlyId 301, ownership/admin
preview gating, `fresh_when` etag, and `Listings::IncrementViewsCountJob`
(1h dedupe per visitor). `Listing` gained `viewable_by?`, `estimated_arrival_*`,
`similar_to`/`more_from_store`, `ancestors` (Category) and display helpers;
`Listings::Search` gained dimension facets + selected-option labels.
All strings in 6 locale files (parity test green).

Gotchas solved: optional `(:locale)` route segment must not get a `defaults:`
(shadows cookie/Accept-Language negotiation) — request paths carry the locale
through `LocaleConcern#default_url_options` instead; listing fixtures would
poison global-scope Search tests and skip tsvector triggers under COPY, so
the browse catalog is a setup factory (`create_browse_catalog`); Ruby `do`
blocks bind to the outer `render` call in ERB (use `{}` with render locals).

`bin/rails test` 147 green; `bin/rubocop` clean; tailwind build OK. Not
committed — awaiting user review.

## 2026-11-19 — Phase 1b-ii-a: mega menu, home page, store pages, demo seed (uncommitted)

Data-driven navigation + marketing pages on top of the 1b-i browse stack.
`NavigationMenu` service builds the header menu (8 top items) from the
Category tree + curated merchandising links (budget ProductLabels, GPU
chipset FilterOptions, theme SellerTags); missing records are skipped
silently so a partial catalog still renders. Items are Marshal-safe Structs
cached per locale on a `cache_stamp` (category timestamps + sell-to-us
flag); the header/drawer fragment-cache on the same stamp. Desktop dropdowns
use the `mega_menu` Stimulus controller (hover-intent, Esc/arrow keys,
aria-expanded); the mobile drawer uses `<details>` accordions. New item →
`search_path(sort: "newest")`; chipset links → `/c/gpus?specs[gpu_chipset][]=…`.

Home page rewritten around a new `HomePage` service: section id-lists cached
~6 min keyed on a data_version (`Listing.maximum(:updated_at)` + locale),
views reload with `with_includes`/`in_order_of`. Sections: deals hero
carousel (`hero_carousel` Stimulus controller; static hero fallback), 3
category tiles, PC Finder banner, theme tiles (seller tags), 4 listing
scrollers (newest/discounts/featured/recently-sold — each hidden when
empty), sell CTA, testimonials, trust strip → `/pages/trust` ("trust" added
to `PagesController::PAGES` + i18n keys).

Storefront: `resources :stores, only: :show, path: "s", param: :slug`.
`StoresController` (skinny; `tab` param listings|about|reviews inside one
`turbo-frame#browse_results` reusing the browse sidebar/results partials;
404 via `render_not_found`). `Listings::Search` extended with `params["store"]`
and `include_sold` (sold sorted last via a `sold_last_sql` CASE, also
applied on the relevance path); `Browseable#run_search(store:)` opts in.
Header: banner/logo/verified badge/stats/follow+message CTAs; vacation-mode
banner shows `store.vacation_message` or the localized fallback. Listing
cards gained a SOLD overlay + store link (cache key bumped to `card/v2`).

Demo seed: `db/seeds/development/demo.rb` loaded by `db/seeds.rb` only when
`Rails.env.development? && ENV["DEMO"]=="1"` (documented in README). Creates
~30 Faker ES users (`@demo.example.com`), 8 stores (3 business, 1
vacation-mode) and ~240 listings built from real categories, filter
definitions/options, labels and theme tags — discounts, featured slots,
sold history, some pending_review, ES provinces. Skips itself once ≥200
demo listings exist (idempotent). `DEMO=1 bin/rails db:seed` ×2 verified.

Gotchas solved: the Psych-based locale merge left a stray top-level
`:unicode: true` key in all 6 yml files — under i18n this crashed every
`I18n.t` with `no implicit conversion of true into Hash` (removed); store
view strings must live under `stores.show` (lazy scope from
`views/stores/show`), not `store.show` — missing keys surfaced as
translation_missing spans in tests, keys renamed in all 6 files; one ERB tag
in stores/show had corrupted bytes (`%>` written as `}}`) — only caught when
the view first rendered in a test. Faker 3.8 keyword nits: `Internet.username(separators:)`,
`Lorem.paragraphs(number:)`. `Faker::Internet` fails under the app's i18n
config while `:unicode` junk is present — keep locale roots clean.

Tests: +16 (home empty/with-data ×2 locales, mega-menu curated+chipset
links, sell-to-us promo flag gating, NavigationMenu service ×4, store show
sold-last ordering/scoping/tabs/vacation/404, demo seed never loaded in
test env). `bin/rails test` **163 green**; `bin/rubocop` clean; tailwind
build OK. Not committed — awaiting user review.

## 2026-11-19 — PC Finder step 1: games + performance scores (uncommitted)

PC Finder (6 steps) groundwork. New `games` table (slug unique, name,
position, active, `demand` jsonb benchmark targets like
{"1080p":{"60":20,"144":45,"240":70}}, `cpu_weight` decimal(4,2) default
0.3) + `Game` model (`required_score(resolution, fps)`, `active` scope
ordered by position, `has_one_attached :image`). `performance_score`
integer added to `filter_options` (per machine-value benchmark) and
`listings` (cached, partial index on status/performance_score where
published). New `Listings::PerformanceScorer`: gpu score from the
`gpu_model` filter option, blended with the `cpu_model` option score as
`gpu*(1-w) + cpu*w` (w=0.3) when present; nil without a scored GPU.
`Listing` recomputes it in `before_save` when specs change.

Files: `db/migrate/20261119170001_create_games.rb`,
`db/migrate/20261119170002_add_performance_score_to_filter_options_and_listings.rb`,
`app/models/game.rb`, `app/services/listings/performance_scorer.rb`,
`app/models/listing.rb`, `test/models/game_test.rb`,
`test/services/listings/performance_scorer_test.rb`.

Gotcha: `:1080p` is not a valid Ruby symbol (starts with a digit) — use
`:"1080p"` in tests.

Verified: migrate → rollback STEP=2 → migrate clean (both reversible);
new tests 10 green; listing/search regression tests 50 green; rubocop
clean on touched files. Not committed.

## 2026-11-19 — PC Finder step 2: score + game seeds (uncommitted)

Seeds for the step-1 machinery. `db/seeds/11_performance_scores.rb`:
relative 0–100 tiers on `gpu_model` FilterOptions (only written when nil,
so admin edits survive; map also covers not-yet-seeded 50-series/GTX
slugs, unknown options stay nil) + new `cpu_model` filter definition
(multi_select, group CPU, sidebar off, sell form on, position 36) with
29 scored CPU options (9800X3D=95 … i7-6700=22) mapped to gaming-pcs,
workstations and cpus. `db/seeds/12_games.rb`: 10 Game rows (fortnite …
marvel-rivals) with `demand` hashes on the same 0–100 scale (4K/240
targets >100 = unattainable). `db/seeds/13_backfill_performance_scores.rb`:
`update_column` backfill of `listings.performance_score` via
`Listings::PerformanceScorer` (skips validations/re-review, deterministic).
`db/seeds/development/demo.rb`: gaming PCs and workstations now always
carry `gpu_model` + `cpu_model` specs (pre-computed option value lists).
`db/seeds.rb` untouched (sorted glob picks 11–13 up); seeds idempotency
test untouched (its `>=` counts still hold).

Verified: `db:seed` ×2 clean (36 defs, 252 options); runner check
`Game.count=10`, 49 scored filter options (20 GPU + 29 CPU), 60 scored
listings (28..95); demo merge path exercised in runner; `bin/rails test`
**173 green**; `bin/rubocop` clean. Not committed.

## 2026-11-19 — PC Finder step 3: Query + Recommender services (uncommitted)

PC Finder steps 3 of 6: the pure-service layer the future controller/views
will sit on. `app/services/pc_finder/query.rb`: `PcFinder::Query` value
object — raw params (incl. ActionController::Parameters) in, safe selections
out: games (≤3 existing active Game slugs, request order, array or
comma-string), resolution (1080p/1440p/2160p), fps (60/144/240), budget
(slug → min/max cents via BUDGETS), case_pref (any/white/black/compact),
cooling (any/air/aio), vibe (existing active SellerTag slug or nil), sort
(best_match/price_asc/price_desc/performance), page (≥1). Invalid values
silently fall back to defaults; `present?` = at least one game;
`to_params` emits a normalized URL hash (drops blanks and page 1).

`app/services/pc_finder/recommender.rb`: `PcFinder::Recommender.new(query)
.call` (also accepts raw params) → `Result` Struct (listings, pagy,
required_score, games, resolution, fps) with `estimated_fps(listing, game)`
= (fps × score / required).round capped at 360, nil-safe. Base scope:
`Listing.visible.in_category(gaming-pcs)` + `performance_score >=` the max
`Game#required_score(resolution, fps)` over the chosen games (nil-safe);
hard filters: budget `price_between`, cooling via `cpu_cooler_type` specs
(`air`/`aio-liquid` seed slugs), compact via `case_form_factor`
(`mini-itx-sff`/`micro-atx`/`mini-tower`). Soft prefs (vibe tag EXISTS,
`case_color` jsonb containment) only boost best_match: match count DESC,
then headroom-per-euro `((score - required) * 1000.0 / GREATEST(price, 1))`
DESC (sanitized SQL, no N+1), `with_includes`, Pagy::Offset limit 24 —
mirrors Listings::Search. Empty query → `Listing.none` + count-0 pagy.

Tests: `test/services/pc_finder/{query,recommender}_test.rb` (28 tests) —
param sanitization/defaults/round-trip, required = max over games, budget,
cooling, compact, vibe/color soft ordering, headroom ranking, sort variants,
estimated_fps (scale/cap/nil), pagination, empty-when-no-games. Records
created per test (spec FilterDefinitions included), no new fixtures.

Verified: `bin/rails test` **201 green** (173 + 28); `bin/rubocop` clean
(133 files). Not committed.

## 2026-11-19 — PC Finder step 4: route, controller & views (uncommitted)

PC Finder steps 4 of 6: the UI layer on top of Query/Recommender (no JS
yet — the `quiz` Stimulus controller ships in step 5).

Routes: `resource :pc_finder, only: :show, path: "pc-finder"` inside the
locale scope → `GET /:locale/pc-finder`.

`app/controllers/pc_finders_controller.rb`: skinny show — `@query =
PcFinder::Query.new(params)`, `@result = PcFinder::Recommender.new(@query)
.call if @query.present?`, `@games = Game.active.with_attached_image`.

Views (`app/views/pc_finders/`): `show.html.erb` (meta-tags hero + quiz +
results-or-discovery-tiles), `_quiz.html.erb` (ONE GET form to
pc_finder_path, `data-controller="quiz"`, `data-quiz-step-value` from
`?step`, hidden page=1 + sort, 7 progress dots `data-quiz-target="dot"`),
`_step.html.erb` (one `<fieldset data-quiz-target="step">` per question:
games checkboxes (`games[]`, ≤3), resolution/fps/budget/case_pref/cooling/
vibe radios as peer-styled chips, Back/Next `data-action="quiz#back|next"`
targets back/next, step 7 holds the `submit` target; without JS all
fieldsets stay visible and the form submits), `_results.html.erb` (answer
summary chips linking `query.to_params.merge("step" => N)`, count, sort
form reusing the existing `filters` controller (`filters#submit` on
change) with hidden fields replaying the query, `listings/card` grid +
`browse/pagination` reuse, empty card), `_performance.html.erb` (per-card
block: each chosen game with `result.estimated_fps`, green ≥ target fps /
amber below / muted "not measured"). No params: "PCs by gamer type" tiles
→ `category_path("gaming-pcs", seller_tags: [anime|minimalist|rgb])` and
"Best PCs for <game>" tiles → `pc_finder_path(games: [slug])`.

I18n: `pc_finders.show.*` block appended after `stores` in all 6 locale
files (text edited as YAML; `800_1200`/`1200_2000` budget keys quoted so
Psych keeps them strings). Game names from `Game#name` (untranslated).

Verified: `bin/rails test` **201 green** (no new tests yet — step 6);
`bin/rubocop` clean (134 files); bare render sanity via
`PcFindersController.render(..., layout: false, request:
ActionDispatch::TestRequest.create)` — Application-controller render hits
`application/_quiz` prefix + Devise warden in the layout, so render the
concrete controller without layout: no-result page 50 KB with 7 steps/7
dots/1 submit, result page with 4 cards + 4 green FPS rows. Not committed.

## 2026-11-19 — PC Finder step 5: quiz Stimulus controller + nav links (uncommitted)

JS: new `app/javascript/controllers/quiz_controller.js` (auto-registered via
`pin_all_from` + `eagerLoadControllersFrom`). Matches the view's attributes
exactly: targets step/dot/next/back/submit, actions quiz#next/quiz#back,
value `step` (1-based from `?step=`, NaN/empty falls back to index 0). On
connect hides all steps but the current one; per render: dots swap
bg-cream-300/dark:bg-cream-surface ↔ bg-primary-300 (done) ↔ bg-primary-600
(active, aria-current="step"); Back hidden on first step, Next hidden /
Submit shown on last; Next disabled until the step has ≥1 checked input;
games step caps at 3 checkboxes (disables the unchecked ones when full);
Enter on a step advances (preventDefault only when it actually advances, so
the form still submits normally on the last step); legend focused on change
and on step change; delegated change/keydown listeners removed on
disconnect.

Views: `_step.html.erb` legend gets `tabindex="-1"` so it can receive focus.
`_quiz.html.erb` unchanged (already had `data-quiz-step-value`).

Links: `NavigationMenu#promos` pc_finder promo now `pc_finder_path(locale:)`
(dropped the now-unused `category` arg + call sites); home banner CTA
`nav_entry_path("gaming_pcs")` → `pc_finder_path`. Header top bar has no PC
Finder placeholder (verified).

Verified: `bin/rails test` 201 green; `bin/rubocop` clean (134 files);
`bin/importmap json | grep quiz` shows the pinned controller. Not committed.

## 2026-11-19 — PC Finder step 6: controller tests (feature done)

Added `test/controllers/pc_finders_controller_test.rb` (13 tests, games +
gaming-PC listings created per test — no new global listing fixtures):
quiz render without params (7 `data-quiz-target="step"` fieldsets, game
tiles, gamer-type tiles, no results block via absent sort select); results
with `games[]=valorant&resolution=1440p&fps=144` (80-score PC shown, 40-score
hidden, "192 FPS" = 144*80/60 in the performance block); invalid params
(resolution=8k, fps=999, games[]=unknown, budget=foo) → 200 quiz fallback;
`step=3` → `data-quiz-step-value="3"`; `page=2` pagination (25 equal-score
PCs, budget=800_1200 keeps the setup builds out so page 2 holds the
first-created PC); all 6 locales 200 with no "translation missing" (quiz +
results); mega-menu promo and home banner CTA link to `/en/pc-finder`.

No app bugs found — no app code changed. `project.md` updated: PC Finder
marked done, open items list admin CRUD for games/performance scores
(Phase 7) and real game images. Verified: `bin/rails test` 214 green;
`bin/rubocop` clean (135 files). Not committed.

## 2026-11-19 — Phase 2 step 1: follows + reviews data model

Migrations (both reversible, verified `db:rollback STEP=2` + re-migrate):
`20261119180001_create_follows` (follower_id→users + store_id FKs not null,
unique [follower_id, store_id], store_id index) and
`20261119180002_create_reviews` (store/author→users FKs not null, listing FK
on_delete nullify, order_id bigint **no FK yet** — orders land in Phase 5,
rating smallint (`t.integer limit: 2`; `t.smallint` doesn't exist on the PG
TableDefinition) + check constraint `chk_reviews_rating_range` 1..5,
title/body/seller_reply/seller_replied_at, status string default published,
verified_purchase, unique partial [author_id, order_id] WHERE order_id IS
NOT NULL, [store_id, status, created_at DESC]). `t.references … index: false`
where a composite index covers the FK column.

Models: `Follow` (belongs_to follower User + store counter_cache
:followers_count; uniqueness scoped to follower; self-follow rejected via
`errors.add(:store, :following_own_store)`), `Review` (string enum status
published/hidden, rating numericality 1..5 integer, title ≤120 / body ≤2000,
self-review rejected, scopes published (enum) + recent, `after_commit
recalculate_store_rating` on create/update/destroy).
`Stores::RatingRecalculator` — one `pick(Arel.sql(...))` aggregate
(COALESCE(ROUND(AVG(rating),2),0), COUNT(*)) over published reviews →
`update_columns(rating_avg:, ratings_count:)`; guards `store.persisted?`
because update_columns raises on a destroyed record (store destroy →
dependent reviews → after_commit runs after the store row is gone).

Associations: User has_many :follows (foreign_key follower_id) /
:followed_stores / :reviews_written (Review, foreign_key author_id,
dependent: :destroy) + `following?(store)`; Store has_many :follows /
:followers / :reviews (all dependent: :destroy). Error messages added under
`activerecord.errors.models.{follow,review}.attributes.store.*` in all 6
locales (parity test).

Tests (15 new): follow_test (counter cache + decrement, self-follow,
duplicate, following?, user destroy), review_test (rating bounds incl.
2.5/nil, length caps, self-review, defaults, published/recent scopes),
services/stores/rating_recalculator_test (avg+count on create, 2-decimal
rounding, hide, destroy→reset). **Gotcha:** after_commit never fires under
transactional fixtures (confirmed in Rails 8.1 test_fixtures.rb — pinned
transaction is rolled back), so the recalculator test uses
`self.use_transactional_tests = false`; fixtures reload only DELETEs fixture
tables, so it also needs `teardown { Review.delete_all }`.

Verified: `bin/rails test` 229 green; `bin/rubocop` clean (143 files).
Not committed.

## 2026-11-19 — Phase 2 step 2a: shipping addresses (model + account CRUD)

Migration `20261119180003_create_addresses` (user/country FKs, label/names/
company/street_line1/2/city/province/postal_code/phone, default_shipping bool
default false; **partial unique index [user_id] WHERE (default_shipping)** —
needs an explicit `name:` because `t.references :user` already created
`index_addresses_on_user_id`). Reversible `change`; migrate → rollback →
migrate verified.

Model `Address`: belongs_to user + country; presence on user/country/
first_name/last_name/street_line1/city/postal_code; Spain-only rules in
`validate :validate_spain` (`spain?` = country code ES): province required +
must be a `SpanishProvince` code, postal code `/\A\d{5}\z/`, and postal code
must start with the province code (INE code = first 2 postal digits; Ceuta 51
/ Melilla 52 included). `SpanishProvince` has **no postal-prefix mapping** —
the rule lives in the model. `before_validation` nulls `province` for non-ES;
country must be `Country.enabled` (`errors.add(:country, :not_enabled)`).
Defaults: `after_create :become_default_when_first` (update_column),
`before_save :unset_other_defaults` (update_all) protects the partial unique
index when creating/editing with the checkbox, `make_default!` wraps
unset-others + `update!` in a transaction. `defaults_first` scope,
`formatted_lines`/`to_s`/`full_name`/`province_name`. User: `has_many
:addresses, dependent: :destroy` + `has_one :default_address` (scoped).

Routes (locale scope): `namespace :account { resources :addresses, except:
:show { resource :default, only: :update, controller: "address_defaults" } }`
→ PATCH `/account/addresses/:id/default` (RESTful nested singular resource,
no custom member action). Controllers scope everything through
`current_user.addresses.find` (RecordNotFound → 404; test env renders it via
`show_exceptions = :rescuable`); invalid create/update re-renders the form
with 422 (Turbo-friendly); flash via lazy `t(".success")`. Views
`account/addresses/{index,new,edit,_form}` reuse `devise/shared/error_messages`,
`card`/`input-field`/`btn-*` utilities, province select from
`SpanishProvince.options` + enabled-countries select.

i18n: `activerecord.errors.models.address.attributes.{country.not_enabled,
province.postal_code_mismatch}`, `activerecord.attributes.address.*`, and
`account.addresses.*` + `account.address_defaults.update.success` in all 6
locales (parity test green).

Tests (30 new): `test/models/address_test.rb` (17) +
`test/controllers/account/addresses_controller_test.rb` (13). **Gotcha:**
Warden test-mode `sign_in` injects the user only into the *next* request and
persistence relies on that response's session cookie — a 404 rendered by the
exceptions app drops the Set-Cookie, so the *following* request is anonymous
(302 to sign_in). Controller-test setup warms the session with one successful
GET first. Also: `assert_match` on translated text with an apostrophe fails
against HTML (`&#39;`) — use `assert_select` with `text:`.

Verified: `bin/rails test` 259 green; `bin/rubocop` clean (149 files).
Not committed.

## 2026-11-19 — Phase 2 step 2b: account settings area (uncommitted)

Migration `20261119180004_add_notification_settings_to_users.rb`: users gains
`notification_preferences` jsonb NOT NULL default `{}` (Ruby-literal default),
`marketing_opt_in` boolean NOT NULL default false, `marketing_opt_in_at`
datetime. Reversible `change`; migrate/rollback/migrate cycle verified,
structure.sql regenerated.

User model: `NOTIFICATION_KEYS` (order_updates, messages, offers, price_drops,
saved_search_alerts, followed_store_listings, newsletter) +
`TRANSACTIONAL_NOTIFICATION_KEYS` (first three). `notify?(key, channel =
:email)` reads `{ key => { channel => bool } }` first, then the flat
`{ key => bool }` the form writes, else the default (transactional on, rest
off). **Gotcha:** `Hash#dig(key, channel)` raises TypeError when the stored
value is a plain boolean — read `prefs[key]` then index it only when it is a
Hash. `omniauth_only?` (provider present + encrypted_password blank) hides the
profile email field; `sync_marketing_opt_in_at` before_save stamps/clears the
timestamp; avatar validated (content type ∈ png/jpeg/jpg/webp/gif, ≤5 MB via
`AVATAR_MAX_SIZE`) + `notification_preferences` shape validated.

Routes (locale scope, `namespace :account`): `resource :profile/:password/
:notifications, only: %i[edit update]` (singular RESTful resources, no custom
actions). Controllers: Profiles uses `update_without_password` (email change →
Devise confirmable reconfirmation, `unconfirmed_email`), permits `:email` only
when not omniauth-only; Passwords uses `update_with_password` +
`bypass_sign_in` (session survives rotation); Notifications casts the
checkbox map to real booleans (`ActiveModel::Type::Boolean`) so the jsonb
stays clean — unchecked boxes simply arrive missing (check_box_tag has no
hidden "0"). All skinny: strong params via `params.expect`, 422 re-render.

Account layout: `app/views/account/_sidebar.html.erb` (Profile/Security/
Addresses/Notifications + Delete-account placeholder →
`edit_user_registration_path`; active item from `controller.controller_name`,
address_defaults folds into Addresses; mobile = horizontal scrollable tabs via
`flex overflow-x-auto lg:flex-col`) + `_shell.html.erb` frame. **Gotcha:**
`render("partial") do ... end` + `yield` inside the partial evaluates the
block with the PARTIAL's virtual path — lazy `t(".key")` broke
(`en.account.shell.*` translation missing). Shell instead renders
`yield :account_body`; pages wrap content in `content_for :account_body`
(captured in the page's own context). Addresses index/new/edit wrapped the
same way.

i18n: `account.{sidebar,profiles,passwords,notifications}.*`,
`activerecord.attributes.user.{avatar,first_name,last_name,locale,phone,
username}` (email/password labels come from devise-i18n) and
`activerecord.errors.models.user.attributes.avatar.*` in all 6 locales.
Strings containing ": " must be quoted in YAML (plain scalars can't hold
colon+space).

Tests (26 new): profiles (9: auth, form, omniauth-only hides email, update
ok/422/username-taken, reconfirmation via `unconfirmed_email`, avatar accept/
reject via `Rack::Test::UploadedFile.new(StringIO…)`), passwords (5: incl.
wrong current password rejected + still-signed-in after update), notifications
(6: checkbox per key, pre-checked transactional keys, booleans persisted,
notify? after update, marketing timestamp), user model (6: notify? defaults/
stored/channel-overrides, prefs shape, marketing timestamp, >5 MB avatar).
**Gotchas:** Devise's session salt derives from encrypted_password — clearing
it mid-test invalidates the warm session (sign_in again); `f.check_box
"notification_preferences[key]"` produces `user[notification_preferences[key]]`
(broken nesting) — use `check_box_tag` + explicit id/label.

Verified: `bin/rails test` 285 green; `bin/rubocop` clean (156 files).
Not committed.

## 2026-11-19 — Phase 2 step 3: seller store settings (uncommitted)

Routes: `namespace :seller { resource :store, only: %i[new create edit update] }`
inside the locale scope. Singular on purpose — one store per user, so the URL
never carries an id and other sellers' stores are unreachable by design.

`Seller::StoresController` (skinny): authenticate_user! + `set_store`
(`current_user.store`); new/create bounce to edit when a store exists,
edit/update bounce to new when it doesn't. All writes go through
`Store#assign_settings` + save; 422 re-render on invalid.

Store model: name now `length: { in: 2..60 }` + case-insensitive uniqueness;
`vacation_message` ≤280; `tax_id` via new `SpanishTaxIdValidator`
(app/validators/) — NIF/NIE mod-23 check letter recomputed, CIF format-only
(type letter + 7 digits + digit/A–J control); `before_validation
:normalize_tax_id` (strip spaces + upcase); logo/banner content-type
(png/jpeg/webp) + size (5/8 MB) validations mirroring User#avatar.
`assign_settings` consumes virtual `remove_logo`/`remove_banner` flags and
purges the attachments. **Slug now regenerates on rename**
(`should_generate_new_friendly_id?` → `name_changed? || super`); Store uses
`:slugged` only — no `:history`, so old store URLs stop resolving after a
rename (updated the old "slug stays stable" store_test accordingly).

Views `seller/stores/{new,edit,_form}` use the account shell (`content_for
:account_body`); sections Store profile / Business details / Location /
Policies / Vacation mode. Business fields toggle via plain CSS `:has`
(`.store-form:has(#store_kind_business:checked) .business-fields` in
application.css — no JS, no inline style so CSP stays 'self'). Sidebar gained
a "My store" entry (edit or new depending on `current_user.store`).
**Gotcha:** on a 422 re-render the rejected upload is attached in memory —
preview `image_tag` must be guarded by `attachment&.persisted?` + image
content_type or the variant pipeline raises.

i18n: `seller.stores.*`, `account.sidebar.my_store`,
`activerecord.attributes.store.*` (incl. remove_logo/remove_banner labels for
the virtual checkboxes), `activerecord.errors.models.store.attributes.*` in
all 6 locales (edited as text).

Tests (30 new): validator (12: NIF/NIE/CIF valid+invalid, case/space
insensitivity, blank passes, Store integration) and
seller/stores_controller (18: auth, open-once + redirect loop, 422s for short
name / taken name / missing business identity / bad tax id, business accept,
vacation toggle, logo/banner attach/reject/remove, ownership).
**Gotcha:** Devise confirmable rejects `sign_in` for unconfirmed users — the
:pending fixture can never sign in in controller tests; create a confirmed
user instead. Session warm-up trick reused.

Verified: `bin/rails test` 315 green; `bin/rubocop` clean (160 files).
Not committed.

## 2026-11-19 — Phase 2 step 4: store slug history (301 redirects), follow/unfollow via Stores::FollowsController with turbo_stream, store reviews tab with rating distribution, demo follows/reviews (uncommitted)

Store `:slugged` → `:slugged + :history`; `Store.find_by_param` falls back to
`FriendlyId::Slug` (latest row per slug, scoped by `sluggable_type`) so renamed
stores keep resolving, and `StoresController#show` 301s (`:moved_permanently`)
when `@store.slug != params[:slug]`. New `Store#rating_distribution` — one
grouped query over published reviews, `{ 5 => n, …, 1 => 0 }` in 5→1 order.

Follow: nested `resource :follow, only: %i[create destroy],
controller: "stores/follows"` → `POST/DELETE /s/:store_slug/follow` (singular —
one follow per user+store, no id in URL). `Stores::FollowsController`
(authenticate_user! + `set_store` via `find_by_param`): create builds through
`current_user.follows` (self-follow just fails validation and re-renders),
destroy `find_by(store)&.destroy`; turbo_stream renders
`stores/follows/follow_state` which `turbo_stream.replace`s
`dom_id(store, :follow)` + `dom_id(store, :followers_count)` (counter cache is
SQL-side → `@store.reload` first); HTML fallbacks `redirect_back` with
flash/alert. `_follow_button` partial (hidden on own store, sign-in link for
anonymous, `compact:` variant for the listing seller box — `?compact=1` rides
the form so the stream re-applies styling) replaces the old `#` placeholders
on the store header and `listings/show` seller box; `_followers_count` wraps
the header stat.

Reviews tab: `StoresController#load_reviews` — published+recent, avatar
preloaded, manual `Pagy::Offset` (limit 10, `REVIEWS_PER_PAGE`).
`stores/show` reviews section: avg + `review_stars` + distribution bars
(`Store#rating_distribution`, share-of-total widths) + `_review` cards
(author avatar/initial, stars, title/body, verified-purchase badge, seller
reply block) + `browse/pagination` reuse. `StoresHelper#review_stars` (filled
first `rating` stars, aria label); `star` icon added to `IconHelper`.

Demo seed: 3–12 follows + 3–8 published reviews per store (ratings skewed 5/4,
~70% verified_purchase, ~35% seller replies, backdated `update_columns`) —
seeded after the random counter columns so the counter cache and
`Stores::RatingRecalculator` overwrite them with true values.

i18n: `stores.follow_button.*`, `stores.follows.{create,destroy}.success`,
`stores.review.*`, `stores.show.reviews.{count,distribution,empty}` in all 6
locales (old `show.reviews.placeholder` dropped).

Tests (18 new): `test/controllers/stores/follows_controller_test.rb`
(14 — auth HTML + turbo, create/destroy turbo swaps + counters, self-follow,
HTML fallbacks, unknown slug 404, **Devise 5 gotcha: turbo_stream requests are
treated as navigational, so unauthenticated follow POSTs get a 302 to sign-in,
not 401**); stores_controller_test +3 (301 old slug, reviews tab avg/
distribution/cards/pagination, empty state, reviews hidden for non-published);
store_test +1 (rename keeps old slug resolvable — fixtures bypass FriendlyId so
this needs a model-created store); `create_review` helper in
`catalog_helpers.rb` (call `Stores::RatingRecalculator` manually — after_commit
doesn't fire under transactional fixtures).

Verified: `bin/rails test` 333 green; `bin/rubocop` clean (163 files).
Uncommitted files (`git status --short`):
```
 M app/controllers/stores_controller.rb
 M app/helpers/icon_helper.rb
 M app/models/store.rb
 M app/views/listings/show.html.erb
 M app/views/stores/show.html.erb
 M config/locales/de.yml
 M config/locales/en.yml
 M config/locales/es.yml
 M config/locales/fr.yml
 M config/locales/it.yml
 M config/locales/pt.yml
 M config/routes.rb
 M db/seeds/development/demo.rb
 M test/controllers/stores_controller_test.rb
 M test/models/store_test.rb
 M test/support/catalog_helpers.rb
?? app/controllers/stores/
?? app/helpers/stores_helper.rb
?? app/views/stores/_follow_button.html.erb
?? app/views/stores/_followers_count.html.erb
?? app/views/stores/_review.html.erb
?? app/views/stores/follows/
?? test/controllers/stores/
```

## 2026-11-19 — Phase 2 step 5: header account menu (uncommitted)

Replaced the header's dead account-icon link with a real account area.

- `shared/_account_menu`: signed out → Sign in + Sign up (sign up only when
  `AppSettings.enabled?(:registrations_enabled)` — the setting defaults to
  off, so it is hidden unless explicitly enabled). Signed in → avatar button
  (thumb `resize_to_fill` variant, initials circle fallback) opening the
  existing `dropdown` Stimulus controller's menu, with a name/email header.
- `shared/_account_links` (NEW, shared with the mobile drawer via
  `variant:` local): "Buying" (orders/messages/wishlist = `#` placeholders
  rendered as `aria-disabled` spans with a "Soon" pill — TODO Phases 5/6 —
  plus Account settings), "My store" (owner: Public profile / Seller
  dashboard (soon) / My listings (soon) / Store settings; else Open your
  store), Admin panel (soon, TODO Phase 7) for admin/moderator only, and the
  sign-out `button_to`. Condition uses `current_user.store&.persisted?` —
  the seller form builds an unsaved store on `current_user`, which would
  otherwise crash `store_path` with a nil slug (caught by the seller tests).
- `dropdown_controller.js`: added ArrowUp/ArrowDown roving focus (wraps) —
  the shared controller already had click toggle, outside-click/Esc close,
  aria-expanded and focus-first-item.
- Mobile drawer: signed-in branch now renders `_account_links` (replacing the
  lone sign-out button); signed-out branch gained the Sign up link.
- I18n: new `account_menu.*` section + `nav.sign_up` in all 6 locales.
- Tests: `test/integration/header_account_menu_test.rb` (9 tests: signed-out
  links, registrations-disabled hides sign up, buying links + sign-out form,
  placeholders not links, store owner vs non-owner items, admin/moderator
  see admin item, regular user doesn't).

Verified: `bin/rails test` 342 green; `bin/rubocop` clean (164 files).
Uncommitted files (`git status --short`):
```
 M app/javascript/controllers/dropdown_controller.js
 M app/views/shared/_header.html.erb
 M app/views/shared/_mobile_drawer.html.erb
 M config/locales/{de,en,es,fr,it,pt}.yml
?? app/views/shared/_account_links.html.erb
?? app/views/shared/_account_menu.html.erb
?? test/integration/header_account_menu_test.rb
```

## 2026-11-19 — Phase 2 step 6: GDPR account deletion + data export (uncommitted)

Shipped the two GDPR flows in the account area.

- Migrations `20261119190001` (users `data_export_generated_at`) and
  `20261119190002` (users `deleted_at` + index); `db:rollback STEP=2` +
  `db:migrate` round-trip verified, `db/structure.sql` regenerated.
- **Data export**: routes `account/data_export` (show/create, singular).
  `Accounts::DataExporter` builds the JSON (profile, addresses, notification
  prefs, store + its listings, follows, reviews written), attaches it as
  `User#data_export` (`has_one_attached`) and stamps
  `data_export_generated_at`; `Account::DataExportJob` runs it async. Show
  page explains the export, request `button_to` (disabled while throttled)
  and a `rails_blob_path(…, disposition: "attachment")` download link once
  ready. Throttle = once per 24h via `User::EXPORT_THROTTLE` /
  `User#data_export_throttled?`, checked in the controller before enqueueing
  (flash alert otherwise). Email notification is TODO Phase 6.
- **Account deletion**: routes `account/deletion` (show/destroy, singular —
  deliberately not Devise's registration#destroy, which would delete the row
  and orphan reviews). Show = warning page + confirmation challenge: current
  password, or the username for `omniauth_only?` accounts (constant-time
  compare). Wrong/blank → 422 re-render, account untouched.
  `Accounts::Deleter` in one transaction: AASM `archive!` every non-archived
  listing, store `vacation_mode: true` (unpublishes — all public listing
  scopes exclude vacation stores), destroy addresses, anonymize (email →
  `deleted-<id>@deleted.invalid` with `skip_reconfirmation!`, username →
  `deleted_user_<id>` — hyphens are rejected by the username format
  validation, so the separator is an underscore —, names/phone/
  unconfirmed_email nil, prefs `{}`, marketing off, avatar + data_export
  purged), stamp `deleted_at`. Reviews stay; `stores/_review` renders the
  author as `t("stores.review.deleted_user")` when `author.deleted?`.
- `User`: `deleted?`, `active_for_authentication?` (false when deleted —
  blocks form sign-in and remember-me alike), `inactive_message` → `:deleted`
  (new `devise.failure.deleted` key in all 6 locales).
- Sidebar: "Download my data" section + "Delete account" now points at
  `account_deletion_path` (was the Devise registration placeholder).
- I18n: `account.data_exports.*`, `account.deletions.*`,
  `account.sidebar.download_data`, `devise.failure.deleted`,
  `stores.review.deleted_user` in all 6 locales (text edits).
- Tests: `test/services/accounts/{data_exporter,deleter}_test.rb` (12),
  `test/controllers/account/{data_exports,deletions}_controller_test.rb`
  (15, incl. throttle flash, download link, 422 wrong password, signed-out
  redirect, deleted user refused at sign_in with the `devise.failure.deleted`
  alert), 2 new `user_test.rb` tests (inactive message, throttle window).

Verified: `bin/rails test` 371 green; `bin/rubocop` clean (175 files).
Uncommitted files (`git status --short`):
```
 M app/models/user.rb
 M app/views/account/_sidebar.html.erb
 M app/views/stores/_review.html.erb
 M config/locales/{de,en,es,fr,it,pt}.yml
 M config/routes.rb
 M db/structure.sql
 M test/models/user_test.rb
?? app/controllers/account/{data_exports,deletions}_controller.rb
?? app/jobs/account/data_export_job.rb
?? app/services/accounts/
?? app/views/account/{data_exports,deletions}/
?? db/migrate/2026111919000{1,2}_*.rb
?? test/controllers/account/{data_exports,deletions}_controller_test.rb
?? test/services/accounts/
```

## 2026-11-20 — Phase 3 step 1: seller listings CRUD (uncommitted)

- Routes: `resources :listings` in `namespace :seller`; header + mobile
  drawer "List an item" buttons now go to `new_seller_listing_path`.
- `Seller::ListingsController` (skinny, `params.expect`): scoped to
  `current_user.store` (foreign ids 404 — `render_not_found` moved from
  `Browseable` to `ApplicationController`); `Stores::EnsureForUser` on
  new/create; `new` prefills draft from store (allow_offers_default,
  province/city/postal_code); create/update save drafts only (published
  edits return to pending_review via the model); destroy hard-deletes
  `deletable?` (draft/rejected) else `archive!`; index tabs per status
  with counts from `Listing.status_counts` (one grouped query).
- `Listing`: `TITLE_MIN/MAX_LENGTH`, `#deletable?`, virtual euro
  accessors `price`/`original_price`/`shipping_price` +
  `.euros_to_cents` (garbage → nil; blank shipping → 0).
- Views: new `seller/_shell` + `_sidebar` (Dashboard soon / My listings /
  Store settings; stores pages migrated off the account shell);
  `seller/listings/{index,new,edit,_form}` with grouped category select
  (`Seller::ListingsHelper`), condition radio cards, euro price fields,
  shipping/location/offers, marked Specs + Photos placeholder sections;
  `char_count_controller.js` title counter.
- i18n: `seller.listings.*`, `seller.sidebar.*`, condition descriptions,
  full listing attribute labels in all 6 locales.
- Tests: `test/controllers/seller/listings_controller_test.rb` (20).

Verified: `bin/rails test` 391 green; `bin/rubocop` clean (178 files).
Uncommitted files (this step):
```
 M app/controllers/application_controller.rb
 M app/controllers/concerns/browseable.rb
 M app/models/listing.rb
 M app/views/seller/stores/{edit,new}.html.erb
 M app/views/shared/{_header,_mobile_drawer}.html.erb
 M config/locales/{de,en,es,fr,it,pt}.yml
 M config/routes.rb
?? app/controllers/seller/listings_controller.rb
?? app/helpers/seller/listings_helper.rb
?? app/javascript/controllers/char_count_controller.js
?? app/views/seller/{_shell,_sidebar}.html.erb
?? app/views/seller/listings/
?? test/controllers/seller/listings_controller_test.rb
```

## 2026-11-20 — Phase 3 step 2: dynamic specification fields in the sell form (uncommitted)

**What changed**
- `Seller::ListingsController#listing_params` now permits `specs: {}` (hash of
  arrays/strings) and pipes it through `Listing.sanitize_specs(category, raw)`:
  only the category's form-visible definitions survive; unknown keys, options
  outside the category subtree and unknown option values are dropped; checkbox
  "1"/"0" booleans map to "true"/"false"; range values kept as typed.
- `Listing`: new `.sanitize_specs` whitelist; new validation
  `required_specs_present` guarded by `entering_review_or_published?`
  (status change to pending_review/published — AASM's `submit!` runs it,
  drafts stay incomplete). Error key `errors.messages.missing_required_spec`.
- New Turbo Frame endpoint: `resource :listing_spec_fields, only: :show` →
  `Seller::ListingSpecFieldsController#show` (layout false, auth required,
  `category_id` + optional `listing_id` scoped to `current_user.store` —
  foreign listing ids 404). Renders only the `listing_specs` frame.
- New partial `seller/listings/_specs_fields.html.erb`: every inherited
  `FilterDefinition` with `show_in_listing_form`, grouped by translated group,
  options featured-first (`FilterOption.featured_first` — the association's
  default order scope would otherwise win over a chained `featured_first`).
  multi_select → checkbox chips (`listing[specs][key][]`), single_select →
  select, boolean → hidden "false" + checkbox "true", range → number input +
  unit. `required_in_form` fields marked with *.
- `_form.html.erb`: placeholder replaced by the server-rendered frame; new
  Stimulus `frame_src_controller.js` sets the frame's src on category change
  (clears it when the select is blank).
- i18n: `seller.listings.specs_fields.{prompt,select_prompt,required_note}` +
  `missing_required_spec` in all 6 locales; `form.specs_placeholder` removed.

**Why**: category-driven specs are the last Phase 3 sell-form input before
photos; sanitizing in the model keeps the controller thin and the jsonb
containment queries uniform.

**Files**: `config/routes.rb`, `app/controllers/seller/{listings,listing_spec_fields}_controller.rb`,
`app/models/listing.rb`, `app/views/seller/listings/{_form,_specs_fields}.html.erb`,
`app/views/seller/listing_spec_fields/show.html.erb`,
`app/javascript/controllers/frame_src_controller.js`, `config/locales/*.yml`,
`test/controllers/seller/{listings,listing_spec_fields}_controller_test.rb`,
`test/models/listing_test.rb`.

Verified: `bin/rails test` 401 green; `bin/rubocop` clean (180 files).
Uncommitted files (this step):
```
 M app/controllers/seller/listings_controller.rb
 M app/models/listing.rb
 M app/views/seller/listings/_form.html.erb
 M config/locales/{de,en,es,fr,it,pt}.yml
 M config/routes.rb
 M test/controllers/seller/listings_controller_test.rb
 M test/models/listing_test.rb
?? app/controllers/seller/listing_spec_fields_controller.rb
?? app/javascript/controllers/frame_src_controller.js
?? app/views/seller/listing_spec_fields/
?? app/views/seller/listings/_specs_fields.html.erb
?? test/controllers/seller/listing_spec_fields_controller_test.rb
```

## 2026-11-20 — Phase 3 step 3: listing photos in the sell form (uncommitted)

**What changed**
- Migration `20261120120001_add_image_order_to_listings` (applied): `listings.image_order`
  jsonb `DEFAULT '[]' NOT NULL` — the seller's gallery order (attachment ids as
  strings); plain reversible `add_column` inside `change`.
- `Listing` gallery API: `images=` appends instead of replacing (rebuilds the
  `CreateMany` change from `images.blobs + attachables`, carrying
  `pending_uploads` over); `remove_image_ids=` accepts attachment ids **or blob
  signed ids** (normalized to strings), purges only this listing's matches
  (`purge_later` deletes the rows synchronously), resets the association caches
  and rebuilds any pending append so purged blobs aren't re-attached;
  `image_order=` parses a JSON string or array (blanks dropped);
  `ordered_images` sorts by image_order (attachment id or blob signed id) with
  unordered images falling back to attachment order at the end — first is the
  cover. `snapshot_review_context` uses `@images_before_edit ||=` because
  `remove_image_ids=` snapshots before purging.
- `Seller::ListingsController` permits `image_order`, `images: []`,
  `remove_image_ids: []`.
- `ListingsHelper#listing_picture` and `listings/_gallery.html.erb` use
  `ordered_images` (cover = first in image_order).
- `config/importmap.rb` pins `@rails/activestorage` → `activestorage.esm.js`;
  `application.js` calls `startActiveStorage()` for direct uploads.
- `_form.html.erb` Photos section (step 3b): file input `listing[images][]`
  (multiple, `direct_upload: true`, accept jpeg/png/webp/heic), tile grid of
  `ordered_images` (thumb variant) each with move-left/move-right buttons, a
  draggable grip handle, a `listing[remove_image_ids][]` checkbox and a Cover
  badge on the first; hidden `listing[image_order]` (JSON); "N / max" counter
  from `AppSettings max_images_per_listing`; formats hint + tips list. Tiles
  for pending (failed-save) or non-transformable blobs render a filename
  placeholder instead of a variant (no signed id / `Can't transform` errors).
- New Stimulus `image_uploader_controller.js`: previews picked files via object
  URLs (revoked on disconnect), keeps its own `pendingFiles` list and rebuilds
  `input.files` via `DataTransfer` (the browser replaces the FileList on every
  pick), direct-upload progress bars from `direct-upload:initialize/progress/
  error/end` on the input, drag-and-drop (grip handle) + arrow-button
  reordering, syncs the hidden order field + Cover badge, updates the counter
  and shows an over-limit warning.
- `IconHelper`: new `grip` icon.
- i18n: `photos_placeholder` removed; `form.photos_{add,hint,cover,move_left,
  move_right,drag_hint,remove,too_many,tips_title}` + `form.photos_tips.*`
  added in all 6 locales.

**Why**: the sell form's last Phase 3 input; appending (not replacing) keeps
existing images when only new files are submitted, and the jsonb order column
avoids a join table for a seller-only ordering concern.

**Files**: `db/migrate/20261120120001_add_image_order_to_listings.rb`,
`app/models/listing.rb`, `app/controllers/seller/listings_controller.rb`,
`app/helpers/listings_helper.rb`, `app/helpers/icon_helper.rb`,
`app/views/listings/_gallery.html.erb`, `app/views/seller/listings/_form.html.erb`,
`app/javascript/{application.js,controllers/image_uploader_controller.js}`,
`config/importmap.rb`, `config/locales/*.yml`, `db/structure.sql`,
`test/models/listing_test.rb`, `test/controllers/seller/listings_controller_test.rb`.

Verified: `bin/rails test` 413 green; `bin/rubocop` clean (181 files).
Uncommitted files (3a + 3b):
```
 M app/controllers/seller/listings_controller.rb
 M app/helpers/listings_helper.rb
 M app/javascript/application.js
 M app/models/listing.rb
 M app/views/listings/_gallery.html.erb
 M app/views/seller/listings/_form.html.erb
 M config/importmap.rb
 M config/locales/{de,en,es,fr,it,pt}.yml
 M db/structure.sql
 M test/controllers/seller/listings_controller_test.rb
 M test/models/listing_test.rb
?? app/javascript/controllers/image_uploader_controller.js
?? db/migrate/20261120120001_add_image_order_to_listings.rb
```

## 2026-11-20 — Phase 3 step 4: seller listing lifecycle (submit/pause/sale) (uncommitted)

**What**: lifecycle actions as singular nested resources under the seller
listings, a `Listings::Submitter` service, a turbo-stream row refresh, an
edit-page status banner and a "Save & submit" form button.

- Routes: inside `namespace :seller { resources :listings }` →
  `resource :submission, only: :create`, `resource :pause, only: %i[create
  destroy]` (create = pause, destroy = resume), `resource :sale, only:
  :create` — all `controller: "listings/<plural>"`.
- `Seller::Listings::BaseController`: authenticate_user! + `set_listing` via
  `store.listings.find_by_param` with an ownership re-check (historical-slug
  fallback escapes the store scope); `rescue_from AASM::InvalidTransition` →
  alert; `render_row`/`render_row_alert` respond turbo_stream (replace
  `dom_id(listing)` via `seller/listings/row_update` + the `toasts` area,
  flash.now) or redirect for plain HTML.
- `Listings::Submitter` (service): keeps the `may_submit?` guard (invalid
  transition → Result with the translated `seller.listings.invalid_transition`
  message + `invalid_transition?` flag), then AASM **bang** event `submit!` —
  the non-bang event only changes the state in memory and never saves
  (AASM default persistence: bang = `save!`), so validation failures come
  back as `ActiveRecord::RecordInvalid` → Result with
  `listing.errors.full_messages`. `approve!` afterwards when
  `listing_auto_approve` is on.
- `Seller::Listings::SubmissionsController#create`: success → row refresh /
  index redirect; failure → HTML redirect to **edit** on validation errors
  (fix the listing) or to the **index** on an invalid transition (nothing to
  fix there). `PausesController` (`pause!`/`resume!`) and `SalesController`
  (`Listing#record_offline_sale!`, `reduced` notice with `%{count}`) are thin.
- `Listing`: `record_offline_sale!` (quantity > 1 → decrement, else
  `mark_sold!` → true); `mark_sold` now also transitions **from paused**;
  `image_present_for_review` validation (errors.add(:base,
  :image_required_for_review)) runs with `required_specs_present` when
  `entering_review_or_published?` — submitting without photos is refused.
- `Seller::ListingsController#update`: with the form's `submit_for_review=1`
  button param (top-level, not nested under `listing:`) runs
  `Listings::Submitter` after saving; both outcomes redirect to edit.
- Views: `seller/listings/_row.html.erb` extracted from the index (dom_id =
  turbo target; state-dependent buttons: Submit for review / Pause / Resume /
  Mark as sold / Delete / Archive), `row_update.turbo_stream.erb` (row +
  toasts), edit.html.erb status banner per state (rejected shows the reason,
  published a public link), `_form.html.erb` "Save & submit" secondary
  button (a `<button name value>` so label ≠ submitted value, only when
  `persisted? && may_submit?`); submit label now "Save draft".
- i18n: `seller.listings.invalid_transition`, `row.{submit,confirm_submit,
  pause,resume,mark_sold,confirm_sold}`, `edit.banner_*`, `form.submit_for_
  review`, `update.submitted`, `submissions.create.submitted`,
  `pauses.{create,destroy}`, `sales.create.{sold,reduced}`,
  `errors.messages.image_required_for_review` — all 6 locales.
- Tests: `test/controllers/seller/listings/{submissions,pauses,sales}_
  controller_test.rb` (23), Save & submit + banner tests in the listings
  controller test, model tests for `record_offline_sale!` / paused→sold /
  submit-needs-photo; `catalog_helpers.rb` gained `attach_photo` and
  `publish` now attaches a stub photo first (submit! requires one).
- Gotchas: AASM non-bang events do NOT persist (use bang + rescue
  RecordInvalid); `response.media_type` never includes the charset (assert
  `"text/vnd.turbo-stream.html"`); test param helpers must merge top-level
  flags outside the `listing:` hash.

**Files**: `config/routes.rb`,
`app/controllers/seller/listings/{base,submissions,pauses,sales}_controller.rb`,
`app/controllers/seller/listings_controller.rb`,
`app/services/listings/submitter.rb`, `app/models/listing.rb`,
`app/views/seller/listings/{_row,_form,edit,index,row_update}.html.erb|turbo_stream.erb`,
`config/locales/*.yml`, `test/support/catalog_helpers.rb`,
`test/models/listing_test.rb`,
`test/controllers/seller/{listings_controller_test.rb,listings/*}`.

Verified: `bin/rails test` 447 green; `bin/rubocop` clean (189 files).
