# PCMarket — Project Context

## Status

Phase 4A complete: cart, guest and logged-in checkout, payments and buyer
orders. Sellers have a dashboard, store profile, policies, vacation mode and
payouts pages; every user has RESTful account, address, notification,
data-export and deletion resources. Discovery (Phase 2B) and listing creation
(Phase 3A) remain intact. Seller order management (phase 4B), messaging, offers,
review creation and admin moderation screens remain for later phases.

## Stack

- Ruby 4.0.9, Rails 8.1.4, PostgreSQL 16
- Hotwire (Turbo, Stimulus), import maps, Propshaft, Tailwind CSS 4
- Devise 5 (database authenticatable, registerable, recoverable, rememberable,
  validatable, confirmable, trackable, lockable, omniauthable)
- Pundit (authorisation), Pagy 9 (pagination)
- pg_search (tsearch + trigram), FriendlyId, Ancestry
- rack-attack, meta-tags
- Stripe (Checkout Sessions + signed webhooks); WebMock in tests
- Minitest with fixtures

## Architecture decisions

### Localisation

- `available_locales`: `es`, `en`, `fr`, `de`, `it`, `pt`; default `es`;
  fallbacks `es`, `en`.
- All routes except `/up`, `/robots.txt` and `/sitemap.xml` are wrapped in
  `scope "(:locale)", locale: /es|en|fr|de|it|pt/`.
- `ApplicationController#switch_locale` validates `params[:locale]` and wraps
  each request in `I18n.with_locale`.
- Devise OmniAuth callbacks live outside the locale scope because Devise does
  not support OmniAuth callbacks under a dynamic segment.
- Locale files are split by domain (`models`, `home`, `layout`, `listings`,
  `pages`, `newsletter`, `errors`, `common`, `countries`, `cart`, `checkout`,
  `orders`); every key exists in all six languages.
  `test/i18n/locale_parity_test.rb` enforces parity.
- English is British English (favourite, colour, authorised).
- Footer and drawer language switchers preserve the current path and query.

### Data model

- Bigint primary keys, real foreign keys, `null: false` wherever the domain
  requires a value, indexes on every FK and on filtering/sorting columns.
- Money is stored as integer cents in EUR; country codes are ISO alpha-2
  strings (`ES`, `FR`, `GB`, `DE`, `IT`, `PT`).
- `pg_trgm` and `unaccent` are enabled for search.
- `Setting` stores typed key/value rows, caches under `settings/v1/<key>` and
  falls back to `Setting::DEFAULTS`. The cache is invalidated on save/destroy.
- Soft deletes use `users.deleted_at`; `User.visible` scopes active, undeleted
  accounts.
- Usernames are generated as `Adjective-Animal#1234` from built-in word lists.
- `Listing` workflow is state-machine-style methods (`submit_for_review!`,
  `approve!`, `reject!`, `pause!`, `resume!`, `mark_sold!`), no AASM.
- `Listing.visible` requires published status, stock, an active owner and an
  enabled country. `Listing.on_sale` and `Listing.recently_sold` support home
  sections.
- `Listing::LABELS` and `Listing::TAGS` hold the marketplace label and seller
  tag vocabularies; both are translated under `listings.labels.*` and
  `listings.tags.*`.
- Slugs: FriendlyId on `Store` (name), `Category` (English name) and `Listing`
  (title, with history through `friendly_id_slugs`).
- `Category.find_by_path_slugs` resolves `/c/components/gpus`; `#path_slugs`
  returns the slug chain.
- Reviews recalculate `stores.rating_avg`/`reviews_count` in `after_commit`.
- Orders compute subtotal, commission (only when enabled) and total in
  `Order#compute_totals!`. Orders are buyer-side purchases: `buyer_id` is
  nullable for guests, `buyer_email` is required for guests, and every order
  carries `payment_method`, `locale`, `checkout_token` (unique per seller),
  `guest_access_token` (has_secure_token), `terms_accepted_at` and
  `stock_restored_at`.
- `orders.number` comes from the `order_number_seq` PostgreSQL sequence as
  `PCM-YYYY-NNNNNN`; the sequence is created by a migration and lazily ensured
  for schema-loaded test databases.
- Favourites and follows use counter caches.

### Seeds

- `db/seeds.rb` loads `db/seeds/*.rb` in dependency order: settings, countries,
  regions, categories, filters, games, legal pages, demo data.
- Every seed file is idempotent. Reference data uses `find_or_initialize_by`
  plus `save!`; running the seeds twice produces no duplicates.
- The category taxonomy is two levels. Leaf categories own listings; filter
  assignments on a parent are inherited through `Category#effective_filters`.
- Phase 1 seed categories that are no longer part of the taxonomy are removed
  only when they own no listings, so user data is never destroyed.
- Demo data is created only in development; the administrator is created in
  every non-production environment.

### Design system

- Tailwind v4 `@theme` tokens in `app/assets/tailwind/application.css`:
  brand teal `--color-brand-50..950`, amber `--color-accent-*`, Space Grotesk
  headings, Inter body, 12 px card radius and shared shadow tokens.
- Class-based dark mode via `@custom-variant dark`; an inline head script
  applies the stored/preferred theme before paint.
- UI primitives live in `app/views/shared/` and helper class methods
  (`ui_button_classes`, `ui_badge_classes`, `ui_chip_classes`,
  `ui_input_classes`, `ui_card_classes`).
- Icons are vendored Lucide SVGs read by `ApplicationHelper#icon`.

### Navigation and layout

- `MenuBuilder` caches the mega-menu payload under a key containing the locale
  and `Category.maximum(:updated_at)`.
- Header: sticky, blurred on scroll, autocomplete search, feature-flagged
  "Sell to PCMarket" button, favourites/notifications/cart badges, account
  dropdown, theme toggle and mega menu.
- Mega menu opens on 150 ms hover intent or click, closes on outside click and
  Escape, and shows child categories, label/price quick links and promo cards.
- Mobile uses a left slide-over drawer (focus trap, scroll lock, Escape) and a
  bottom tab bar below 768 px.
- Cookie consent is a Stimulus controller on `<body>`; choices are stored in
  `cookie_consent` for six months. `consent_given?(:analytics)` is available to
  gate future third-party scripts.

### Home page

- `HomeFeed` owns all home queries and uses
  `Listing.visible.includes(:store, :category, images_attachments: :blob)`.
- Sections are cached per locale for five minutes; listing cards are fragment
  cached on `[listing, I18n.locale]` while the viewer-dependent favourite
  button stays outside the cache.
- Sections: hero carousel, promo tiles, PC Finder CTA, shop-by-vibe, scroll
  rows, trust strip, reviews carousel with translated fallback testimonials,
  sell CTA and SEO copy.
- `listings/_card.html.erb` is the shared card used by home, search and
  favourites.

### Search and filtering (Phase 2B)

- `ListingSearch` (`app/services/listing_search.rb`) is the single entry point
  for web, API and saved-search alerts. It normalises params, clamps the query
  to 100 chars and the page to 100, and converts euro inputs to cents. It
  accepts `q`, `category`, `min_price`, `max_price`, `condition[]`, `labels[]`,
  `tags[]`, `f[key][]`, `region_id[]`, `shipping[]`, `free_shipping`,
  `on_sale`, `seller`, `sort` and `page`.
- Spec filters use JSONB containment (`listings.specs @> '{"key":"value"}'`),
  OR-ed inside a key and AND-ed across keys. Only `FilterDefinition` keys that
  are effective for the current category are accepted, which also neutralises
  injection attempts in filter keys.
- `Result` exposes paginated records (Pagy, 24/page), total count (cached 60s),
  active filter chips with removable params, facet counts for effective
  checkbox filters and condition counts.
- Facets are computed with ONE grouped query over
  `jsonb_each_text(listings.specs)` against the relation filtered by category,
  query, price and condition (everything except spec filters), cached 5 minutes
  per (category, q, price, condition, filter keys) digest. Options with zero
  count are hidden unless selected.
- Search UI runs inside a single `turbo-frame#listing_results`; the sidebar,
  toolbar, grid and pagination all live inside it, so filtering only replaces
  the frame. Forms use `data-turbo-action="advance"` for shareable URLs and
  back-button support. Stimulus `filters_controller` submits checkboxes/selects
  immediately and debounces text/price inputs by 400ms, showing skeleton cards
  while loading. The mobile filter sheet contains the same form partial.
- Category pages, `/search` and store listings all reuse the same results
  partial. Store pages pass a store-scoped base relation and an `include_sold`
  toggle, and hide the spec/label/region sections (`compact` mode).
- Indexes added for search: `(status, category_id, published_at DESC)`,
  `(status, price_cents)`, `(status, favorites_count DESC)`,
  `(status, store_id, published_at DESC)`, `(status, region_id, published_at
  DESC)` and a partial `(status, published_at DESC)` for published in-stock
  rows. The existing GIN indexes cover `specs`, `labels`, `tags` and trigram
  title/description.
- Query plan with 5,000 generated listings (rolled back):
  `RAILS_ENV=test bin/rails db:test:prepare` then
  `RAILS_ENV=test bin/rails runner script/search_explain.rb`. The combined
  category + condition + price + shipping + spec query (1,917 matches) uses
  `Index Scan using index_listings_search_category` with the remaining
  predicates as filters; planning 1.7ms, execution 13.5ms, 238 shared buffers
  for the listings scan. The GIN `index_listings_on_specs` remains available
  when the planner prefers containment over the composite index.

### Listing detail, stores and favourites (Phase 2B)

- Detail pages use a 7/5 desktop grid with a sticky buy box, a Stimulus gallery
  (pointer swipe, arrow keys, thumbnails, `<dialog>` lightbox) and a mobile
  sticky price/CTA bar. Images use `resize_to_limit` WebP variants; the first
  is eager + `fetchpriority=high`, the rest lazy.
- View counters use a single `UPDATE` via `Listing.register_view!`, skip bots
  and owners, and remember the last 50 listing ids in the session (also used
  for "recently viewed" on home and detail pages).
- Old slugs resolve through `friendly_id_slugs` and 301 to the current URL.
  Non-visible listings are 404 for strangers but viewable by owners/staff with
  a status banner; sold listings remain public and render SoldOut offers.
- Structured data: Product + Offer (price, currency, availability, item
  condition), BreadcrumbList, and aggregateRating from the store. Search pages
  emit BreadcrumbList + ItemList.
- Store pages have a banner/logo header, professional vs private badge,
  company/tax details, vacation banner, tabs (listings/about/reviews) loaded
  through `turbo-frame#store-panel`, an `include_sold` toggle, review
  distribution bars, sorting and paginated reviews with seller replies.
- Favourites toggle through Turbo Streams: `replace_all` updates every heart
  instance for a listing, the count is replaced separately and cards are
  removed from the favourites grid. A Stimulus controller toggles the heart
  optimistically and restores it if the request fails. Guest intents are stored
  in the session, completed after sign-in and then return to the listing.
- Store follows use a counter cache and Turbo Stream replacement of the button
  and follower count.

### Cart and authentication (Phase 2B)

- Guest carts use a signed permanent `cart_token`; user carts use `user_id`.
  A Warden `after_authentication` hook merges guest items into the user cart,
  capping quantities by stock and deleting the guest rows.
- Cart item creation rejects own and non-visible listings, caps quantity by
  stock and responds with Turbo Streams that update the header badge and append
  a toast. "Buy now" adds the item, then redirects to the cart.
- Devise views use a two-column shell with rotating testimonials. Sign-up
  requires the terms checkbox (`users.terms_accepted_at`), records marketing
  opt-in and respects `Setting registrations_enabled`. The header login link
  opens the same form inside a Turbo Frame `<dialog>` with a full-page fallback.
  Development mail uses `letter_opener` mounted at `/letter_opener`.
- Saved searches are created from the current query string, listed under
  `/saved_searches` and in the account page, and can toggle notifications with
  Turbo Streams. Reports are one-open-per-user-and-listing.

### Listing creation and seller board (Phase 3A)

- The seller form is a single page with five sections (category, photos,
  details, price, delivery). `listing_form_controller` adds counters, progress,
  drag ordering, file previews and client-side type/size validation; the form
  remains usable without JavaScript.
- The category picker uses root `<details>` cards and leaf links. A leaf link
  navigates only `turbo-frame#listing_specs` to
  `new_listing_path(category_id:)` / `edit_listing_path(category_id:)`, so
  already typed fields are untouched. The frame carries the hidden
  `listing[category_id]`.
- `ListingForm` is the single writer for the seller form: it assigns scalars,
  keeps specs only for the category's effective filter keys (stored as
  strings), attaches/removes/reorders images, forces quantity 1 for private
  sellers, enforces the image requirement on submit and applies the
  draft → pending_review/published transition.
- Images are uploaded through Active Storage direct uploads
  (`@rails/activestorage` pinned in the import map). Display order is stored in
  blob `metadata["position"]` and every image render uses
  `Listing#ordered_images`.
- Money inputs use virtual attributes (`price=`, `original_price=`,
  `shipping_price=`) that accept `1.299,50`, `1299.50` and `1299`.
- A listing created without a store calls `User#ensure_store!`, which creates
  an individual store named after the username.
- Published listings stay live after price, quantity, shipping or description
  edits. Title, category or image changes set `Listing#requires_re_review?`
  from `saved_changes` plus media changes and return the listing to
  `pending_review` when approval is enabled.
- Destroy archives (`status: archived`) when order items exist and hard-deletes
  otherwise. Duplication copies the listing as a draft and reuses image blobs.
- Nested member routes model lifecycle actions: `listing_submission` (submit),
  `listing_pause` (POST pause, DELETE resume) and `listing_sale` (mark sold).
  `Seller::ListingsController#index` filters by status with counts and search;
  bulk pause/resume/delete go through `Seller::BulkListingActionsController`
  and the `BulkListingAction` service, which whitelists the action.
- Listing detail uses grid placement so the buy box follows the title on
  mobile and sits beside the gallery on desktop; the stats row wraps by group
  with `whitespace-nowrap` items. Zero-cost shipping with shipping enabled
  renders the translated "Free shipping" label in the buy box, cards and
  shipping section.

### Seller area and account settings (Phase 3B)

- `Seller::BaseController` supplies authentication, the `seller` layout and
  `seller_store` (`User#ensure_store!`). The layout has a store header card and
  responsive nav: desktop sidebar, mobile scrolling tabs.
- `SellerDashboard` caches one aggregate payload for 5 minutes per store and
  emits KPI cards with 30-day deltas, a server-rendered inline SVG orders chart
  (with an accessible `<title>/<desc>` and visually hidden table), action links,
  store completeness and recent listings. Conditional `FILTER` aggregates keep
  the dashboard under 30 queries including chrome.
- Seller settings are singular resources: `seller/store`, `seller/store_policy`,
  `seller/vacation` and `seller/payout`. Logo (≤5 MB) and banner (≤8 MB) accept
  JPEG/PNG/WebP; `image_preview_controller` previews uploads.
- `Store` uses FriendlyId history. Renames archive the previous slug and old
  store URLs 301 to the current slug. `Store#completeness` weights logo,
  description, both policies and location at 25 points each.
- Professional stores require `company_name` and `tax_id`; Spanish tax IDs are
  validated by `SpanishTaxIdValidator` (NIF/NIE module-23, CIF control digit).
- Vacation mode keeps listings visible but disables purchase in the listing buy
  box and rejects `CartItemsController#create` with a translated alert.
- Online payouts are not implemented: `seller/payout` explains the order-based
  payment model and shows a disabled Stripe Connect button.
- Account settings are singular resources under `account`: profile
  (`show/update`), password, addresses, notification preferences, data export
  and deletion. `Account::BaseController` supplies the `account` layout.
- Addresses promote the first address to default, clear other defaults inside
  the save transaction and promote a fallback when the default is deleted.
- `users.notification_preferences` is a jsonb hash (defaults true except the
  newsletter, which mirrors `accepts_marketing`). `User#notify_by_email?` is the
  read API; `User#update_notification_preferences!` is the writer.
- `UserDataExport` produces the GDPR articles 15/20 JSON download from the
  signed-in user only. `User#soft_delete!` anonymises email/username/names,
  purges the avatar, archives listings and retains orders.
- Email changes go through Devise reconfirmable (`unconfirmed_email`); passwords
  require the current password except for OAuth-only accounts, which can set one.
- `ApplicationController#switch_locale` resolves explicit locale, then the
  signed-in user's locale, then the best `Accept-Language` match, then Spanish.
  Selecting a locale while signed in persists it to `users.locale`.

### Cart, checkout and payments (Phase 4A)

- `CartSummary` (`app/services/cart_summary.rb`) is the single read model for
  the cart page, header badge and checkout. It groups cart rows by seller and
  store, clamps quantities to current stock, flags sold/unavailable/vacation
  items, excludes unavailable items from totals and returns per-group shipping
  (sum of item shipping, free, or pickup-only).
- The cart page renders one card per store with item thumbnails/condition/
  price, a stepper only when listing stock is above one, remove and
  save-to-favourites. The sidebar shows subtotal, shipping, an internal
  platform-fee note when commissions are enabled (the buyer is never charged
  it), estimated total, buyer-protection box and the checkout/guest-login CTAs.
  `Setting checkout_enabled` hides the CTAs and shows the translated disabled
  notice.
- Cart mutations (quantity, remove, favourite) respond with Turbo Streams that
  replace `#cart-groups`, `#cart-summary` and `#cart-count`. Saving to
  favourites is a nested `cart_item_favorite` resource.
- Checkout is a singular `checkout` resource with a nested `confirmation`.
  `Checkout::Form` validates contact email, per-seller shipping/local pickup,
  the shared shipping address (saved address or typed fields), enabled country,
  Spanish province/postal-code prefix, payment availability and both legal
  acknowledgements. The page uses four `<details>` steps with a small Stimulus
  controller that opens the next step.
- `Checkout::PlaceOrder` runs in one transaction: it re-validates the summary,
  locks every listing `FOR UPDATE` in id order, re-checks visibility/stock,
  creates one pending_payment order per seller with title/price snapshots,
  decrements stock (marking zero-stock listings sold), optionally saves the
  address and clears purchased cart rows. `checkout_token` (hidden field,
  unique per seller) makes double submits return the original orders.
- Payment providers implement `start(orders, return_urls)` and
  `handle_webhook(request)`: `BankTransfer` (default, IBAN/beneficiary/deadline
  from settings), `CashOnPickup` (only when every group is pickup-only) and
  `Stripe` (Checkout Session per order, metadata order ids, signed webhook,
  idempotent paid marking and stock restoration on expiry). `Payments::
  Availability` computes the offered methods from settings, the Stripe key and
  the pickup state.
- `ExpireUnpaidOrdersJob` runs hourly in every environment and cancels
  pending_payment bank-transfer orders older than `payment_deadline_days`,
  restoring stock and relisting sold-out listings.
- Confirmation shows order numbers per seller, totals, payment instructions,
  next steps and guest links. `OrderMailer#placed_buyer` and `#placed_seller`
  send HTML + text in the order locale; the seller mail respects
  `email_order_updates`.
- Buyer orders are `/orders` (filter tabs All/To pay/In progress/Completed/
  Cancelled, number/title search) and `/orders/:number` (status timeline,
  items, seller card, delivery address, payment instructions, totals).
  `OrderPolicy` allows buyers only; guests use the `guest_access_token` query
  parameter. `Orders::CancellationsController` lets a buyer cancel an unpaid
  order and restores stock.
- New settings defaults: `payment_bank_transfer_enabled`, `bank_iban`,
  `bank_beneficiary`, `payment_deadline_days`, `stripe_enabled`.

### Performance guardrails

- `ListingSearch::INCLUDES` preloads store, category, region, user and image
  attachments/blobs. Cards never call `category.root` or `user.store`; root
  slugs come from a cached `Category.root_slug_map` and seller names prefer the
  preloaded store.
- `MenuBuilder` fetches roots and direct children in two queries and builds
  paths from slugs without walking ancestry.
- `Setting` caches the whole small settings table under one key.
- Anonymous search pages send `Cache-Control: public, max-age=60` and
  `fresh_when` on `[locale, params digest, Listing.maximum(:updated_at)]`;
  listing pages use `fresh_when` on `[listing, locale, store.updated_at]`.
- N+1 guard: `test/integration/search_performance_test.rb` renders a category
  page with 24 listings and asserts fewer than 25 SQL queries via
  `ActiveSupport::Notifications`.

### SEO and security

- `ApplicationController#set_default_meta_tags` sets title, description,
  canonical, hreflang alternates plus `x-default`, Open Graph and Twitter tags.
- JSON-LD `Organization` + `WebSite` with `SearchAction` is emitted once in the
  layout.
- `/robots.txt` and `/sitemap.xml` are handled by `SeoController` outside the
  locale scope. `SitemapBuilder` caches output for an hour and splits into a
  sitemap index after 45,000 URLs.
- A strict nonce-based CSP allows self assets, Google Fonts, data/blob images
  and the import map. `Permissions-Policy` and `Referrer-Policy` are set in
  `config/initializers/security_headers.rb`.
- Production forces SSL and uses `solid_cache`; development uses
  `memory_store`, toggled with `bin/rails dev:cache`.

### Authorisation

- `ApplicationController` includes `Pundit::Authorization`; unauthorised
  requests redirect back with `errors.not_authorized`.
- `ListingPolicy` lets owners edit/delete their listings and moderators/admins
  approve or reject. `ListingPolicy::Scope` hides non-visible listings from the
  public.
- Admin routes require `current_user.staff?`; non-staff visitors are redirected
  to the home page with a translated alert.

## Code map

```
app/controllers/application_controller.rb   locale, meta tags, menu, staff guard,
                                            search params
app/controllers/concerns/search_rendering.rb shared search/category/store rendering
app/controllers/home_controller.rb          home feed + recently viewed
app/controllers/listings_controller.rb      index/show/new/create/edit/update/destroy,
                                            specs Turbo Frame, views, SEO, caching
app/controllers/listings/                   submissions, pauses, sales member resources
app/controllers/seller/listings_controller.rb  seller board (tabs, counts, search)
app/controllers/seller/bulk_listing_actions_controller.rb
app/controllers/seller/base_controller.rb      auth, seller layout, seller_store
app/controllers/seller/dashboard_controller.rb KPI dashboard
app/controllers/seller/{stores,store_policies,vacations,payouts}_controller.rb
                                            singular store settings resources
app/controllers/seller/orders_controller.rb seller sales placeholder
app/controllers/cart_controller.rb           grouped cart read model
app/controllers/cart_items_controller.rb     cart mutations + Turbo Streams
app/controllers/cart_items/favorites_controller.rb move cart row to favourites
app/controllers/checkouts_controller.rb      checkout form, PlaceOrder, provider redirect
app/controllers/checkout/confirmations_controller.rb  confirmation page
app/controllers/orders_controller.rb         buyer order history/detail + guest token
app/controllers/orders/cancellations_controller.rb    cancel unpaid buyer order
app/controllers/payments/stripe_webhooks_controller.rb signed Stripe webhook
app/controllers/account_controller.rb        account profile show/update
app/controllers/account/                     password, addresses, notification
                                            preferences, data export, deletion
app/services/seller_dashboard.rb             cached dashboard aggregates
app/services/user_data_export.rb             GDPR JSON export
app/validators/spanish_tax_id_validator.rb   NIF/NIE/CIF checksum validation
app/services/listing_form.rb                seller form writer (specs/images/status)
app/services/bulk_listing_action.rb          whitelisted bulk pause/resume/delete
app/controllers/categories_controller.rb    category path resolution
app/controllers/stores_controller.rb        store header, tabs, reviews
app/controllers/{cart,cart_items,favorites,follows,reports,saved_searches}_controller.rb
app/controllers/users/registrations_controller.rb
app/controllers/{conversations,orders,account,pc_finder,pages,legal_pages,sell_offers}_controller.rb
app/controllers/{search_suggestions,seo,newsletter_subscribers}_controller.rb
app/controllers/admin/dashboard_controller.rb
app/controllers/seller/dashboard_controller.rb
app/services/listing_search.rb              search, facets, chips, sorting
app/services/cart_summary.rb                 cart groups, warnings, stock clamping
app/services/checkout/form.rb                checkout validation
app/services/checkout/place_order.rb         transactional multi-seller order creation
app/services/payments/{provider,bank_transfer,cash_on_pickup,stripe,availability}.rb
                                             payment providers and offered methods
app/jobs/expire_unpaid_orders_job.rb         unpaid bank-transfer sweep
app/mailers/order_mailer.rb                  buyer/seller order emails
app/policies/order_policy.rb                 buyer order authorisation
app/services/cart_merger.rb                 guest -> user cart merge
app/services/menu_builder.rb                cached mega-menu payload
app/services/home_feed.rb                   home queries
app/services/search_suggestions.rb          listing/category/store suggestions
app/services/newsletter_subscription.rb     idempotent subscription statuses
app/services/sitemap_builder.rb             XML sitemap + index
app/helpers/application_helper.rb           icons, UI classes, money, JSON-LD, specs
app/views/layouts/application.html.erb      global head, header, main, footer, auth dialog
app/views/shared/                           layout partials, pagination, filters, toasts
app/views/listings/index.html.erb           search/category page
app/views/listings/_results.html.erb        Turbo Frame results + sidebar + sheet
app/views/listings/_filters.html.erb        shared desktop/mobile filter form
app/views/listings/show.html.erb            detail page, gallery, buy box
app/views/listings/_form.html.erb           five-section seller form
app/views/listings/_specs.html.erb          category-driven specs Turbo Frame
app/views/listings/_actions.html.erb        seller row actions menu
app/views/seller/listings/index.html.erb    tabs, table/cards, bulk actions
app/views/seller/dashboard/show.html.erb    KPIs, SVG chart, actions, recent
app/views/seller/{stores,store_policies,vacations,payouts,orders}/
                                            seller settings screens
app/views/{cart,checkouts,checkout,orders}/
                                             cart, checkout, confirmation, buyer orders
app/views/order_mailer/                      placed_buyer/placed_seller HTML + text
app/views/account/                          profile, password, addresses,
                                            notifications, privacy/deletion
app/views/layouts/{seller,account}.html.erb shared area layouts
app/views/stores/show.html.erb              store header, tabs
app/views/stores/tabs/                      listings/about/reviews panels
app/views/favorites/                        heart button/count partials
app/views/devise/                           styled authentication screens
app/views/listings/_card.html.erb           shared listing card
app/views/home/index.html.erb               home sections + recently viewed
app/assets/tailwind/application.css         design tokens and base styles
app/assets/images/icons/                    vendored Lucide SVGs
app/javascript/controllers/                 theme, drawer, mega-menu, autocomplete,
                                            carousel, dropdown, modal, tabs, toasts,
                                            cookie consent, scroll rows, back-to-top,
                                            filters, option list, view toggle,
                                            favourite toggle, gallery, share, auth modal
config/routes.rb                            locale scope + SEO + phase 2B resources
config/initializers/warden_hooks.rb         guest cart merge on sign-in
config/initializers/content_security_policy.rb
config/initializers/security_headers.rb
config/locales/                             six-language UI strings (+ domain files)
db/seeds.rb                                 loader
db/seeds/*.rb                               taxonomy and reference data
script/search_explain.rb                    5k listing EXPLAIN ANALYZE
test/integration/                           home, SEO, search pages, auth, performance
test/services/listing_search_test.rb
test/services/cart_summary_test.rb
test/services/checkout/place_order_test.rb
test/services/payments/availability_test.rb
test/jobs/expire_unpaid_orders_job_test.rb
test/mailers/order_mailer_test.rb
test/integration/{checkout,orders,stripe_webhook}_test.rb
test/system/checkout_flow_test.rb
test/system/                                responsive + auth modal
test/i18n/locale_parity_test.rb
test/seeds_test.rb
```

## Open items for later phases

- Admin moderation screens (approve/reject queue) for listings; seller-side
  submission already exists.
- Review creation flow after a completed order (the `Review` model and store
  aggregate exist, but no buyer UI).
- Seller order management (phase 4B): marking orders paid/shipped/delivered and
  fulfilling bank-transfer orders. `seller/orders` is still a placeholder.
- Admin tools to mark bank transfers paid and to resolve disputes/refunds.
- Messaging: conversations render placeholders; `conversations#create` only
  opens the thread. Offers, unread counters and notifications are pending.
- Saved-search alert delivery (the model stores exact replay params under
  `filters["_search"]`, but no background job sends alerts yet).
- Seller dashboard performance is cached for five minutes; order-level events
  do not invalidate it immediately.
- Store dashboard deltas for listing views and average rating are shown without
  a period comparison because views are stored as a running total.
- Online payouts (Stripe Connect) and seller payout history are pending.
- Discount codes are visible in the seller navigation as a disabled item.
- Store tabs currently render the active panel inline for SEO and load other
  tabs through Turbo Frame navigation; `loading="lazy"` placeholders can be
  added if the panels grow heavier.
- Mobile "Load more" navigates to the next page inside the results frame
  instead of appending; true infinite append can be added with a stream
  endpoint.
- Google sign-in is shown only when `GOOGLE_CLIENT_ID` and
  `GOOGLE_CLIENT_SECRET` are configured.
- Real social profile URLs and legal copy per locale.
- API endpoints (ListingSearch is already API-ready).
