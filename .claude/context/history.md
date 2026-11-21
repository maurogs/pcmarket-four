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

## 2026-11-21 — Phase 3B: seller area, store settings and account settings

### What changed

- Added a shared seller layout (`layouts/seller.html.erb`) with a store header
  card and responsive navigation: desktop sidebar, mobile horizontal tabs.
  Dashboard, My listings, My sales, Store profile, Store policies, Vacation
  mode, a disabled Discount codes item and Payouts.
- Replaced the dashboard placeholder with `SellerDashboard`, a cached
  (5 minutes per store) aggregate service: seven KPI cards with 30-day deltas,
  an accessible inline SVG orders chart with a visually hidden data table,
  action-needed links, store completeness progress and recent listings.
  All metrics are aggregated with conditional `FILTER` queries to stay below
  30 SQL queries per request.
- Added `Seller::OrdersController#index` with an empty state for phase 4.
- Added singular seller resources: `seller/store` (profile edit/update with
  logo/banner uploads and Stimulus previews), `seller/store_policy`,
  `seller/vacation` and `seller/payout`. Profile validates the 3–50 character
  name, 2,000 character description and professional company/tax details.
- `Store` now uses FriendlyId history; renames archive the previous slug and
  `StoresController#show` 301-redirects old URLs. Added `Store#completeness`
  (0–100) and attachment size/format validations.
- Added `SpanishTaxIdValidator` with NIF, NIE and CIF check-digit algorithms.
- Added the platform buyer-protection card (locked) to store policies and a
  vacation mode that shows a banner on listings and rejects cart additions.
- Added singular account resources: `account` (show/update), `account/password`,
  `account/addresses` (full CRUD), `account/notification_preferences`,
  `account/data_export` and `account/deletion`. The shared account layout uses
  the same responsive navigation pattern.
- Addresses now promote the first address to default, clear other defaults in
  the save transaction and promote a fallback when the default is deleted.
- Added `users.notification_preferences` (jsonb) with defaults true except the
  newsletter, which maps to `accepts_marketing`; `User#notify_by_email?` is the
  single read API.
- Added `UserDataExport` (GDPR articles 15/20) returning only the signed-in
  user's records as a JSON download, and `User#soft_delete!` to anonymise the
  account, purge the avatar, archive listings and keep orders.
- Added reconfirmation-aware email changes, E.164-ish phone validation, public
  username format validation and account language persistence. `switch_locale`
  now falls back to the signed-in user's locale, then the best
  `Accept-Language` match, then Spanish.
- Updated the header account dropdown and mobile drawer with the new account
  and seller routes.
- Added integration tests for the seller area and account settings, unit tests
  for the Spanish tax validator, and locale keys in all six languages.

### Why

Phase 3B gives sellers a complete operational area and gives every user a
RESTful account/privacy area, closing the remaining profile and settings gaps
before checkout and messaging arrive in later phases.

### Files touched

`app/controllers/{application,account}_controller.rb`,
`app/controllers/account/*`, `app/controllers/seller/*`,
`app/models/{address,store,user}.rb`,
`app/services/{seller_dashboard,user_data_export}.rb`,
`app/validators/spanish_tax_id_validator.rb`,
`app/views/layouts/{_head,application,seller,account}.html.erb`,
`app/views/seller/**`, `app/views/account/**`,
`app/views/shared/{_header,_mobile_drawer}.html.erb`,
`app/views/listings/show.html.erb`,
`app/javascript/controllers/image_preview_controller.js`,
`app/helpers/application_helper.rb`, `config/routes.rb`,
`config/locales/phase3b.*.yml`, `db/migrate/*notification_preferences*`,
`db/seeds/demo.rb`,
`test/{integration/seller_area_test.rb,integration/account_settings_test.rb,validators/spanish_tax_id_validator_test.rb}`,
`test/fixtures/stores.yml`, `.claude/context/project.md`.

## Phase 4A — cart, checkout and payments

### What changed

- Replaced the cart placeholder with a seller-grouped cart. `CartSummary`
  (`app/services/cart_summary.rb`) is the single read model for the cart page,
  header badge and checkout: it groups rows by seller/store, clamps quantities
  to stock, flags sold/unavailable/vacation items as warnings, excludes them
  from totals and computes per-seller shipping (sum of item shipping, free or
  pickup-only).
- Cart UI now has store cards, item thumbnails, condition, stepper (only when
  stock > 1), remove, save-to-favourites, per-seller shipping/subtotal, order
  summary, buyer-protection box, recommendations from cart categories and the
  empty state. Remove/quantity/favourite actions stream replacements for
  `#cart-groups`, `#cart-summary` and `#cart-count`.
- `resources :cart_items` gained a nested `favorite` resource
  (`CartItems::FavoritesController`) that moves an item to favourites.
- Added singular `resource :checkout` with a nested `confirmation` resource and
  `Orders::CancellationsController`. Stripe webhooks live outside the locale
  scope at `POST /webhooks/stripe`.
- Added `Checkout::Form` (server validation for contact, per-seller delivery,
  address/province/postal code, payment availability and the two legal
  acknowledgements) and `Checkout::PlaceOrder` (one transaction, `FOR UPDATE`
  listing locks, one order per seller, price/title snapshots, stock decrement
  and sold-out status, cart clearing, `checkout_token` idempotency, order
  numbers from `order_number_seq`).
- Order numbers now come from a PostgreSQL sequence (`PCM-YYYY-NNNNNN`) instead
  of a count; `buyer_id` is nullable and guest orders store `buyer_email` plus a
  `has_secure_token` guest access link (`/orders/:number?token=`).
- Added `Payments::Provider`, `Payments::BankTransfer`, `Payments::CashOnPickup`,
  `Payments::Stripe` and `Payments::Availability`. Bank transfer shows the
  configured IBAN/beneficiary/reference; cash on pickup is offered only when all
  groups are pickup-only; Stripe Checkout sessions are created per order and
  webhooks verify `STRIPE_WEBHOOK_SECRET`, mark paid idempotently, and restore
  stock on expiry/failure.
- Added `ExpireUnpaidOrdersJob` (hourly recurring in development, test and
  production) to cancel old unpaid bank-transfer orders and relist stock.
- Added payment settings defaults: `payment_bank_transfer_enabled`,
  `bank_iban`, `bank_beneficiary`, `payment_deadline_days`, `stripe_enabled`.
- Added buyer order history (`OrdersController#index/show`) with filter tabs,
  number/title search, status timeline, items, seller card, delivery address,
  payment instructions, totals, guest-token access and unpaid cancellation.
- Added `OrderMailer#placed_buyer` and `#placed_seller` (HTML + text, buyer
  locale, seller notification preference) delivered through Solid Queue.
- Split locale domains into `cart.*`, `checkout.*` and `orders.*` in all six
  languages and removed the old cart block from `phase2.*`.

### Why

Phase 4A closes the purchase loop: buyers can review grouped carts, check out
as a guest or account holder, pay by bank transfer, cash on pickup or Stripe,
and track orders, while sellers receive prepared orders and stock is protected
against overselling.

### Files touched

`app/controllers/{cart,cart_items,checkouts,orders}_controller.rb`,
`app/controllers/{cart_items,checkout,orders,payments}/**`,
`app/services/{cart_summary,checkout/**,payments/**}.rb`,
`app/models/{order,setting}.rb`, `app/policies/order_policy.rb`,
`app/mailers/order_mailer.rb`, `app/views/order_mailer/**`,
`app/jobs/expire_unpaid_orders_job.rb`,
`app/views/{cart,checkouts,checkout,orders}/**`,
`app/helpers/application_helper.rb`,
`app/javascript/controllers/checkout_controller.js`, `config/routes.rb`,
`config/recurring.yml`, `config/locales/{cart,checkout,orders}.*.yml`,
`config/locales/phase2.*.yml`, `db/migrate/*checkout*`,
`db/migrate/*order_number_sequence*`, `db/schema.rb`,
`test/services/{cart_summary,checkout/**,payments/**}_test.rb`,
`test/jobs/expire_unpaid_orders_job_test.rb`,
`test/{integration/checkout_test.rb,integration/orders_test.rb,integration/stripe_webhook_test.rb,mailers/order_mailer_test.rb,system/checkout_flow_test.rb}`,
`Gemfile`, `.claude/context/project.md`.

## Phase 4B — Order lifecycle, seller fulfilment, reviews and notifications

### What changed

- Added `OrderEvent` (`order_id`, nullable `actor_id`, `kind`, `data` jsonb,
  `created_at`) and order columns `disputed_at`, `refunded_at`,
  `refund_required` and `late_shipment_notified_at` through a reversible
  migration. Every order now records a `placed` event on create.
- `Order` gained transactional, guarded lifecycle methods: `mark_paid!`,
  `ship!`, `mark_ready_for_pickup!`, `confirm_delivery!`, `complete!`,
  `cancel!`, `open_dispute!`, `resolve_dispute!`, `refund!` and
  `flag_late_shipment!`. Each locks the row, validates the from-state and
  actor, writes an `OrderEvent`, restores/re-lists stock on cancellation and
  increments `stores.sales_count` on completion.
- Added carrier and dispute-reason vocabularies, per-carrier tracking URLs,
  inspection-window helpers, `buyer_details_visible?`, seller filter scopes and
  seller order search.
- Added `Notifier` (in-app notification + preference-aware mail enqueue) and
  `OrderNotifier` (buyer/seller/admin fan-out for every order event). Order
  emails are HTML + text through a shared `order_mailer/event` template in the
  recipient locale.
- Added `AutoDeliverOrdersJob`, `AutoCompleteOrdersJob` and
  `LateShipmentReminderJob` plus recurring schedules. Late shipment sends one
  reminder and auto-cancels at twice the deadline with a refund flag.
- Buyer orders gained delivery confirmation, dispute (reason, details, up to
  five photos) and review resources, a real event timeline, tracking links and
  review display.
- Replaced the seller orders placeholder with tabbed sales management
  (counts, search, table/cards), a detailed order page with privacy-gated
  address, commission/net payout, shipment, pickup, cash payment and
  cancellation actions, review replies, CSV export and a printable packing
  slip. Dashboard revenue now uses `total_cents - commission_cents`.
- Reviews now enforce 20–1000 character bodies, blocked words from
  `Setting blocked_words`, completed-order rules in policy/controller and
  respect `reviews_enabled`; seller replies are shown and stored once.
- Added the notifications page, mark-all-read and per-notification read
  resources, a lazy Turbo Frame header bell and real-time badge replacement via
  `Turbo::StreamsChannel`.
- Added settings defaults `inspection_window_days`,
  `auto_complete_after_delivery_days`, `auto_delivered_after_shipping_days`,
  `seller_ship_deadline_days`, `support_email` and `blocked_words`.
- Added six-language locale domains for order events, sellers orders, reviews
  and `notifications.*`; parity remains enforced.

### Why

Phase 4B closes the post-purchase loop: sellers can fulfil and communicate,
buyers can confirm receipt, dispute and review, and both sides get consistent
in-app and email updates while stock and sales metrics stay correct.

### Files touched

`app/models/{order,order_event,review,notification,setting}.rb`,
`app/services/{notifier,order_notifier,profanity_filter,seller_order_export}.rb`,
`app/services/seller_dashboard.rb`, `app/jobs/auto_*`, `app/jobs/late_*`,
`app/mailers/order_mailer.rb`, `app/views/order_mailer/event.*`,
`app/controllers/{orders,notifications}_controller.rb`,
`app/controllers/{orders,notifications,seller/orders,seller}/**`,
`app/policies/order_policy.rb`, `app/helpers/application_helper.rb`,
`app/views/{orders,notifications,seller/orders,listings,stores,shared}/**`,
`app/views/layouts/{application,seller,account,packing_slip}.html.erb`,
`config/routes.rb`, `config/recurring.yml`,
`config/locales/{orders,phase2,phase3b,notifications}.*.yml`,
`db/migrate/*order_events*`, `db/schema.rb`, `test/**`.

## Phase 5 — Messaging, offers, follows and saved-search alerts

### What changed

- Replaced the conversation placeholders with a full inbox: two-pane desktop
  list + thread, mobile list/thread navigation, Chats/Offers/Archived/Blocked
  tabs, mark-all-read, unread counters and a live header badge over
  `[user, :inbox]`.
- Added message composer behaviour (autosize, Enter/Shift+Enter, 2,000 chars),
  day separators, read receipts, system messages and per-participant Turbo
  Stream appends.
- Added `MessageSafetyScanner` (email, ES/EN phone, IBAN, Bizum/PayPal
  Friends/Western Union/off-platform transfer) with `messages.flagged` and a
  recipient warning banner.
- Added blocks in either direction, conversation reports through the polymorphic
  `Report`, and a 30-messages-per-10-minutes sender limit.
- Added offers with bounds, 48-hour expiry (`ExpireOffersJob`), accept / decline /
  counter (`OfferResponse`), accepted-offer cart pricing
  (`cart_items.offer_price_cents`, `offer_expires_at`), cart/checkout price
  snapshots, notifications and preference-aware emails.
- Added `NotifyFollowersJob`, `SavedSearchAlertJob`, `SavedSearchDigestJob`
  (daily 08:00 Europe/Madrid) and `PriceDropAlertJob`; extended saved searches
  with a frequency enum, rename, notify toggle and replay.
- Added the `/account/following` page and set `config.time_zone` to
  `Europe/Madrid` with UTC storage.
- Added `bin/rails context:html`, a dependency-free Markdown renderer and
  standalone light/dark HTML context views; refreshed `project.es.md` and the
  phase status/open items.
- Added model, service, job, mailer, integration and system tests for the new
  flows.

### Why

Phase 5 completes buyer–seller communication and keeps discovery alive after
the order: offers can convert into a reserved cart price, followers and saved
searches receive targeted alerts, and favourites react to price drops without
exposing contact details or moving payments off-platform.

### Files touched

`db/migrate/20261122110000_add_phase5_messaging_offers_and_alerts.rb`,
`app/models/{conversation,message,block,cart_item,listing,saved_search,user}.rb`,
`app/services/{conversation_starter,message_notifier,message_safety_scanner,offer_response}.rb`,
`app/services/{cart_summary,checkout/place_order}.rb`,
`app/jobs/{notify_followers,saved_search_alert,saved_search_digest,price_drop_alert,expire_offers}_job.rb`,
`app/mailers/{message,saved_search,favourite}_mailer.rb`,
`app/mailers/order_mailer.rb`, `app/views/{message_mailer,saved_search_mailer,favourite_mailer}/**`,
`app/controllers/conversations_controller.rb`, `app/controllers/conversations/**`,
`app/controllers/messages/**`, `app/controllers/{blocks,reports,saved_searches}_controller.rb`,
`app/controllers/account/following_controller.rb`,
`app/views/{conversations,messages,messaging,account/following}/**`,
`app/views/{listings,stores,orders,shared,saved_searches,account}/**`,
`app/helpers/application_helper.rb`,
`app/javascript/controllers/composer_controller.js`, `app/views/layouts/*.html.erb`,
`config/{routes,application,recurring}.yml`, `config/locales/messaging.*.yml`,
`lib/tasks/context.rake`, `.claude/context/{project,project.es,project.html,project.es.html}`,
`test/**`.

## Phase 6A — Admin foundation, dashboard, moderation and users

### What changed

- Added the `/:locale/admin` namespace with `Admin::BaseController` (staff
  guard, `admin` layout, Pundit admin policies, `Admin::Auditable`) and the
  admin sidebar/topbar Stimulus controllers.
- Built the cached admin dashboard (`Admin::Dashboard`), including 7-day KPI
  trends, 30-day inline SVG charts, latest pending listings/orders/users and a
  Solid Queue/Active Storage/database health panel under the 40-query budget.
- Built the moderation queue with image review, category-median scam warning,
  message-safety scan, duplicate-image checksum detection, seller context,
  approve/reject/feature actions, bulk approve and keyboard shortcuts.
- Added listing administration (filters, sorting, bulk whitelist, full edit form
  with labels/status/featured/performance/game-FPS JSON/specs, detail history).
- Added user administration (filters, CSV export, suspension, ban, roles,
  confirmation, password reset, GDPR soft delete, impersonation) and store
  administration (verification, vacation mode, edits).
- Added `ListingMailer#approved/#rejected` and listing notifications through
  `Notifier`; every admin mutation is written to `admin_audit_logs`.
- Added six-locale `admin.<locale>.yml` files and Devise inactive messages.
- Added an audit log index, global admin search and translated coming-soon
  placeholders for phase 6B/6C sections.
- Added integration/system tests for access control, moderation emails,
  suspicious price/duplicate image warnings, bulk actions, suspension, role
  guards, impersonation, CSV export, dashboard query budget and the moderator
  approval system flow. Stabilised system-test viewport/cookie isolation and the
  pre-existing flaky composer typing.

### Why

Phase 6A gives staff a single operational surface for the marketplace: the
dashboard exposes marketplace health and revenue, the moderation queue protects
buyers from scams and duplicates, and user/store tools enforce policy with a
complete audit trail. Remaining admin areas can now be added incrementally in
6B/6C using the shared UI kit.

### Files touched

`db/migrate/20261122120000_add_moderation_fields_to_users.rb`,
`app/controllers/admin/**`, `app/controllers/concerns/admin/auditable.rb`,
`app/policies/admin/**`, `app/services/admin/**`, `app/mailers/listing_mailer.rb`,
`app/views/listing_mailer/**`, `app/views/layouts/admin.html.erb`,
`app/views/admin/**`, `app/views/shared/_impersonation_banner.html.erb`,
`app/helpers/admin_helper.rb`,
`app/javascript/controllers/{admin_sidebar,admin_queue}_controller.js`,
`app/models/user.rb`, `app/services/notifier.rb`,
`app/controllers/application_controller.rb`, `app/views/layouts/{application,seller}.html.erb`,
`config/routes.rb`, `config/locales/admin.*.yml`, `config/locales/notifications.*.yml`,
`test/**`, `.claude/context/{project,project.es}.md`.

## 2026-11-21 — Phase 6B admin operations

### What changed

- Added admin order management: filtered/sortable index with totals and CSV
  export, full order detail, bank-transfer reconciliation with deadline
  countdown, bulk mark-paid summary, cancellation, refund with reference,
  buyer/seller email resends and audited internal notes (`OrderNote`).
- Added dispute operations: queue and detail with dispute photos, read-only
  conversation, timeline, notes, and resolution by refund (administrator) or
  release (staff). Resolution messages fan out as notifications and locale-aware
  emails to both parties.
- Added report operations: filters, status counts, reportable preview, related
  reports, resolve with hide-listing / suspend-user / unpublish-review actions,
  dismiss, bulk dismiss and reporter notifications.
- Added review moderation: filters, detail with order link, publish/unpublish
  with store rating recalculation, seller-reply visibility, and admin-only
  deletion.
- Linked dashboard dispute/report/pending-payment cards to the new screens and
  added cached one-minute sidebar badges.
- Added six-locale admin, notification and order-mailer strings, tests for the
  new flows, and synchronised project context (English and Spanish).

### Why

Phase 6B closes the operational loop opened in 6A: staff can now reconcile
payments, resolve disputes and moderate reports/reviews from the admin panel,
with every destructive action authorised and audited.

### Files touched

`db/migrate/20261122130000_create_order_notes_and_refund_reference.rb`,
`app/models/{order,order_note,review}.rb`, `app/services/order_notifier.rb`,
`app/mailers/order_mailer.rb`, `app/controllers/admin/**`,
`app/policies/admin/**`, `app/services/admin/**`, `app/views/admin/**`,
`app/views/{listings,stores,orders,seller/orders}/**`,
`app/helpers/admin_helper.rb`, `app/controllers/admin/base_controller.rb`,
`config/routes.rb`, `config/locales/{admin,notifications,orders}.*.yml`,
`test/**`, `.claude/context/{project,project.es}.md`.
