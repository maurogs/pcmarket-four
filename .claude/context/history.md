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
