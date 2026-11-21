# Change history

## 2026-11-21 — Phase 1: foundation and data model

### What changed

- Added gems: devise, omniauth-google-oauth2,
  omniauth-rails_csrf_protection, pundit, pagy (~> 9), pg_search, ancestry,
  friendly_id, meta-tags, rack-attack, tailwindcss-rails (v4), rails-i18n,
  devise-i18n, faker, http.
- Installed Tailwind CSS 4 (`Procfile.dev`, `bin/dev`,
  `app/assets/tailwind/application.css`).
- Configured I18n for `es`, `en`, `fr`, `de`, `it`, `pt` (default `es`,
  fallbacks `es`/`en`) and added locale-scoped routes, `switch_locale` and
  `default_url_options` in `ApplicationController`.
- Added the placeholder `HomeController#index` and a Tailwind layout that sets
  `<html lang>` from the current locale.
- Created 14 reversible migrations with real foreign keys, indexes, array/jsonb
  columns, check constraints, GIN/trigram indexes and the `pg_trgm`/`unaccent`
  extensions.
- Added the full model layer: countries, regions, settings, users, stores,
  categories, filters, listings, favourites, follows, saved searches,
  conversations, messages, blocks, cart items, addresses, orders, order items,
  reviews, notifications, reports, legal pages, audit logs, API tokens, sell
  offers, newsletter subscribers and games.
- Added Pundit `ApplicationPolicy` and `ListingPolicy`, plus Google OmniAuth
  callbacks.
- Added six-language locale files for models, home, errors, common and
  countries.
- Added idempotent seeds with reference data and a development demo account.
- Added valid fixtures for every model and tests for settings caching, listing
  validations/transitions/scopes/search, category filter inheritance, order
  totals, review rating recalculation, username generation, favourite counter
  cache, saved-search matching and locale routing.
- Updated the README with setup, localisation and OAuth instructions.

### Why

Phase 1 establishes a reliable, fully localised base and a complete schema so
later phases can add UI and workflows without reshaping the data model.

### Files touched

`Gemfile`, `Gemfile.lock`, `Procfile.dev`, `bin/dev`,
`app/controllers/application_controller.rb`, `app/controllers/home_controller.rb`,
`app/controllers/users/omniauth_callbacks_controller.rb`,
`app/models/*`, `app/policies/*`, `app/views/home/index.html.erb`,
`app/views/layouts/application.html.erb`, `config/application.rb`,
`config/routes.rb`, `config/environments/test.rb`,
`config/initializers/devise.rb`, `config/initializers/rack_attack.rb`,
`config/locales/*`, `db/migrate/*`, `db/seeds.rb`, `test/fixtures/*`,
`test/models/*`, `test/integration/home_test.rb`, `test/test_helper.rb`,
`README.md`, `.claude/context/project.md`.

## 2026-11-21 — Phase 2: taxonomy, design system, layout, home and SEO

### What changed

- Split `db/seeds.rb` into dependency-ordered, idempotent files under
  `db/seeds/`: settings, countries, regions, categories, filters, games, legal
  pages and demo data. Seeded 52 Spanish provinces plus Ceuta and Melilla,
  French, British, German, Italian and Portuguese regions, the full two-level
  category tree with six-language names, 43 filter definitions with translated
  options and category assignments, 12 games and legal pages.
- Added `Listing::LABELS`, `Listing::TAGS`, `Listing.on_sale`,
  `Listing.recently_sold`, `Category.menu_roots`,
  `Category.find_by_path_slugs` and `Category#path_slugs`.
- Built the Tailwind v4 design system in `app/assets/tailwind/application.css`
  with brand teal and amber tokens, Space Grotesk/Inter typography, class-based
  dark mode, reduced-motion support and shared component classes.
- Vendored 56 Lucide SVG icons and added the `icon(name, class:)` helper.
- Added shared UI partials: card, badge, chip, price tag, star rating, empty
  state, flash toasts, modal, dropdown, tabs, accordion, skeleton loader and
  pagination. Added button/badge/chip/input helper classes.
- Rebuilt the global layout with announcement bar, sticky header, autocomplete
  search, account dropdown, mega menu, mobile drawer, mobile tab bar, footer
  with newsletter signup, cookie consent and back-to-top button.
- Added Stimulus controllers for theme, announcement dismissal, toasts,
  dropdowns, modal dialogs, mobile drawer focus trap, mega-menu hover intent,
  carousel, autocomplete, tabs, scroll rows, sticky header, back-to-top and
  cookie preferences.
- Built the home page: deals carousel, promo tiles, PC Finder band, shop by
  vibe, five cached scroll rows, trust strip, reviews carousel with fallback
  testimonials, sell CTA and SEO copy. Added the shared listing card with
  cached fragments, WebP variants, fallback placeholder, labels, price tags,
  condition and specification chips.
- Added the complete Phase 2 route set with translated placeholder screens for
  listings, categories, stores, cart, favourites, inbox, orders, account,
  seller dashboard, PC Finder, sell-to-us, legal pages and admin.
- Added SEO infrastructure: meta-tags defaults, canonical URLs, hreflang plus
  x-default, Open Graph/Twitter defaults, inline SVG favicon, generated OG PNG,
  manifest, JSON-LD Organization/WebSite with SearchAction, robots.txt and a
  cached sitemap with alternates and 45k URL index splitting.
- Added a strict nonce-based CSP, Permissions-Policy, Referrer-Policy, forced
  SSL in production and enabled the memory cache in development.
- Added newsletter subscription and confirmation with a localised mailer.
- Added integration tests for every locale, hreflang, JSON-LD, robots, sitemap,
  search suggestions, mega menu, cookie banner, announcement bar, feature flag,
  newsletter flows and admin access; added seed idempotency and locale parity
  tests.

### Why

Phase 2 gives PCMarket its identity, navigation, taxonomy and crawlable
foundation so Phase 3 can focus on the marketplace flows (search, listings,
stores, checkout) without reshaping the UI or reference data.

### Files touched

`db/seeds.rb`, `db/seeds/*`, `app/models/{category,listing}.rb`,
`app/services/*`, `app/controllers/*`, `app/helpers/application_helper.rb`,
`app/mailers/{application,newsletter}_mailer.rb`, `app/views/**`,
`app/assets/tailwind/application.css`, `app/assets/images/**`,
`app/javascript/controllers/*`, `config/routes.rb`, `config/locales/*`,
`config/initializers/{content_security_policy,security_headers}.rb`,
`config/environments/production.rb`, `public/*`, `test/**`, `README.md`,
`.claude/context/project.md`.

## 2026-11-21 — Phase 2B: search, category, detail, stores, favourites, auth

### What changed

- Added `ListingSearch` (params, price conversion, JSONB containment, facets,
  active filter chips, sorting, Pagy pagination, cached counts) plus search
  performance indexes and `script/search_explain.rb`.
- Rebuilt `/search`, category pages and store listing tabs around one Turbo
  Frame results partial with a sticky desktop sidebar, mobile filter sheet,
  auto-submitting forms, skeleton loading, grid/list toggle, empty states,
  save-search, pagination and load-more.
- Added category label tabs, breadcrumbs, SEO copy, canonical/noindex/prev/next
  rules, BreadcrumbList and ItemList JSON-LD, and anonymous HTTP caching.
- Built the listing detail page: WebP gallery with swipe/keyboard/lightbox,
  sticky buy box, cart/report/favourite/share actions, seller card, specs,
  description auto-linking, game FPS bars, shipping/returns, similar and
  seller rows, reviews, recently viewed and mobile sticky CTA.
- Added slug-history 301s, owner/staff previews for hidden listings, sold
  listings for SEO, view counters and Product/Breadcrumb JSON-LD.
- Built store pages with professional/private disclosure, vacation banner,
  follow/message/share, listings/about/reviews tabs and review distribution.
- Implemented favourites with Turbo Stream heart replacement, optimistic UI,
  guest favourite intents, grid filters and sold/unavailable states.
- Implemented guest/user carts, `CartMerger` + Warden hook, stock caps,
  own/non-visible listing guards, header badge streams and cart page.
- Added follows, reports and saved searches resources with Turbo Stream
  toggles and translated feedback.
- Styled all Devise screens in a two-column shell, added terms acceptance,
  marketing opt-in, registration flag support, password hints, the header
  login dialog and `letter_opener_web` in development.
- Fixed header/nav overflow: removed nav icons, limited the bar to seven roots
  plus a "More" mega menu, made items nowrap with hidden-scroll overflow,
  removed the duplicate nav theme toggle and hid the publish button below
  desktop. Fixed mobile overflow and added a responsive system test.
- Added service tests, integration tests for every new flow, an N+1 guard
  (<25 queries for 24 listing cards) and responsive/auth-modal system tests.
- Added `phase2.*` locale files in es/en/fr/de/it/pt and `listings.conditions`
  / `listings.statuses` translations that the pre-existing duplicate YAML keys
  made unreachable.

### Why

Phase 2B turns the shell into a usable marketplace: buyers can search, filter,
inspect listings and stores, save searches and favourites, and sign in, while
the query/facet/caching architecture stays ready for the API and alert jobs.

### Files touched

`app/services/listing_search.rb`, `app/services/cart_merger.rb`,
`app/controllers/**`, `app/models/{listing,category,store,user,saved_search,report}.rb`,
`app/helpers/application_helper.rb`, `app/views/**`, `app/javascript/controllers/*`,
`config/routes.rb`, `config/initializers/{warden_hooks,devise}.rb`,
`config/environments/development.rb`, `config/locales/phase2.*.yml`,
`db/migrate/20261121220000_add_search_performance_indexes.rb`,
`db/seeds/categories.rb`, `script/search_explain.rb`, `test/**`,
`.claude/context/project.md`.

## 2026-11-21 — Phase 3A: listing creation, image uploads and seller board

### What changed

- Implemented the seller listing form (`new`/`create`/`edit`/`update`/`destroy`)
  as a five-section page with a sticky section nav, progress bar, inline field
  errors and an anchored error summary. The form works without JavaScript and
  is enhanced by `listing_form_controller` (counters, drag reorder, file
  previews, client-side type/size checks, progress tracking).
- Added a two-step category picker (root `<details>` cards → leaf links). Leaf
  selection loads only the `listing_specs` Turbo Frame from
  `new_listing_path(category_id:)` / `edit_listing_path(category_id:)`, so
  typed values elsewhere in the form survive.
- Spec fields are generated from the leaf category's effective filter
  definitions and stored as strings in `listings.specs`. `ListingForm` drops
  any key that is not an effective filter for the chosen category.
- Active Storage direct uploads are wired through importmap (`@rails/activestorage`)
  with previews, removal and drag ordering. Order is persisted in blob
  `metadata["position"]`; every image render uses `Listing#ordered_images`.
- Added `Listing#price=`, `#original_price=` and `#shipping_price=` virtual
  attributes accepting `1.299,50`, `1299.50` and `1299`. Enforced private-seller
  quantity of 1, image limits, ES postcode format and the
  `max_active_listings_per_user` quota.
- Added the first-listing store bootstrap: `User#ensure_store!` creates an
  individual store named after the username for listings created without one.
- Published edits that change title, category or images call
  `Listing#requires_re_review?` (based on `saved_changes` plus media changes)
  and return the listing to `pending_review` when approval is required.
- Archiving: destroying a listing with order items sets `status: archived`;
  otherwise it is destroyed.
- Added RESTful member resources: `listing_submission` (submit for review),
  `listing_pause` (POST pause / DELETE resume) and `listing_sale` (mark sold).
- Added `Seller::ListingsController#index` with status tabs and counts, search,
  responsive table/cards, per-listing actions (view, edit, pause/resume, mark
  sold, duplicate, delete) and a bulk-actions form. Duplication reuses image
  blobs and creates a draft.
- Added `Seller::BulkListingActionsController` backed by
  `BulkListingAction` with a `pause`/`resume`/`delete` whitelist.
- Fixed free shipping display (zero shipping or the free flag now renders the
  translated "Free shipping" in the buy box and cards) and reworked the listing
  detail grid so the buy box follows the title on mobile. The stats row wraps
  by group instead of breaking labels.
- Added `test/fixtures/files/gpu.jpg` (generated with vips), integration tests
  covering the full lifecycle and a system test that creates, uploads and
  submits a listing end to end. Locale keys added in all six languages and the
  Tailwind build refreshed.

### Why

Phase 3A closes the listing supply loop: sellers can create, submit, edit and
manage listings, images upload directly and the moderation workflow stays
intact for published content.

### Files touched

`app/controllers/listings_controller.rb`, `app/controllers/listings/*`,
`app/controllers/seller/*`, `app/models/{listing,user}.rb`,
`app/services/{listing_form,bulk_listing_action}.rb`,
`app/views/listings/{_form,_specs,_actions,new,edit,show}.html.erb`,
`app/views/seller/listings/index.html.erb`, `app/views/shared/_price_tag.html.erb`,
`app/helpers/application_helper.rb`, `app/javascript/controllers/{listing_form,bulk_select}_controller.js`,
`app/javascript/application.js`, `config/{routes.rb,importmap.rb}`,
`config/locales/{listings,models,errors}.*.yml`,
`test/{integration/listings_management_test.rb,system/listing_creation_test.rb}`,
`.claude/context/project.md`.
