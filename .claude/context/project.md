# PCMarket — Project Context

## Status

Phase 6B complete: admin operations for orders and payment reconciliation,
disputes, reports and review moderation, with dashboard links and cached
sidebar badges. Phase 6A admin foundation (dashboard, listing moderation,
users, stores, audit log and impersonation) is intact. Phase 5 internal chat
with conversations, unread counters and real-time messages, offers with
accepted-offer cart pricing, blocks and message safety warnings; follower
notifications, instant and daily saved-search alerts and favourite price-drop
alerts are intact. Phase 4B order lifecycle (paid, shipped, delivered,
completed, cancelled, disputed, refunded), seller fulfilment screens, buyer
delivery confirmation/disputes/reviews, order notifications with email fan-out
and real-time badge updates remain intact. Discovery (Phase 2B), listing
creation (Phase 3A) and checkout/payments (Phase 4A) are unchanged. Catalogue,
content, marketing and settings admin screens remain for phase 6C and link to
translated placeholder pages.

## Phase status

| Phase | Scope | Status |
|---|---|---|
| 1 | Foundation, localisation, design system | Complete |
| 2B | Discovery, search, listings, stores, favourites, auth | Complete |
| 3A | Listing creation and seller board | Complete |
| 3B | Seller area and account settings | Complete |
| 4A | Cart, checkout and payments | Complete |
| 4B | Order lifecycle and seller fulfilment | Complete |
| 5 | Messaging, offers, follows and saved-search alerts | Complete |
| 6A | Admin foundation, dashboard, moderation, users and stores | Complete |
| 6B | Admin orders, payments, disputes, reports and reviews | Complete |

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
  `orders`, `notifications`, `messaging`, `admin`); every key exists in all six languages.
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
- Order lifecycle is a state machine of guarded, transactional methods in
  `Order`: `mark_paid!`, `ship!`, `mark_ready_for_pickup!`,
  `confirm_delivery!`, `complete!`, `cancel!`, `open_dispute!`,
  `resolve_dispute!`, `refund!` and `flag_late_shipment!`. Each transition
  locks the row, validates the from-state and actor, writes an `OrderEvent`
  and sends notifications through `OrderNotifier`.
- `OrderEvent` stores `order_id`, nullable `actor_id`, `kind`, `data` jsonb and
  `created_at`; the buyer and seller timelines read it chronologically. Orders
  additionally carry `disputed_at`, `refunded_at`, `refund_required` and
  `late_shipment_notified_at`.
- Cancellation restores stock and re-lists sold listings exactly once through
  `stock_restored_at`. Completion increments `stores.sales_count`. `Order`
  exposes carrier tracking URLs for ten carriers and inspection-window helpers.
- `Notifier.call(user, kind, params:, url:)` creates a `Notification` and
  enqueues the matching order email when `email_order_updates` is enabled.
  Notifications broadcast badge replacements on
  `turbo_stream_from user, :notifications`.
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

### Order lifecycle and seller fulfilment (Phase 4B)

- `Order` lifecycle transitions are guarded, transactional model methods. Admin
  can mark paid/refund/resolve disputes; sellers mark cash-on-pickup paid, ship
  with a carrier from `Order::CARRIERS` and tracking (optional only for
  `other`), mark local pickups ready, and cancel paid orders with a refund
  flag. Buyers confirm receipt and open disputes inside the inspection window.
- `OrderNotifier` fans out in-app notifications and locale-aware HTML/text
  emails for paid, shipped, delivered, completed, cancelled, dispute, refund
  and late-shipment events. Guest buyers receive email without an account.
  Admin dispute mail goes to `Setting.support_email`.
- Solid Queue recurring jobs: `AutoDeliverOrdersJob` (shipped older than
  `auto_delivered_after_shipping_days`), `AutoCompleteOrdersJob` (delivered
  older than `inspection_window_days`, skips disputes) and
  `LateShipmentReminderJob` (one reminder after `seller_ship_deadline_days`,
  auto-cancel with refund after twice that).
- Buyer order actions are nested singular resources: `delivery_confirmation`,
  `dispute` (new/create with up to five photos), `review` and `cancellation`.
- Seller `/seller/orders` has tabs (to ship, awaiting payment, shipped,
  completed including delivered, cancelled/refunded, disputes), counts, search,
  desktop table/mobile cards, CSV export, an order page with privacy-gated
  address (paid only), commission line when non-zero, net payout, tracking,
  shipment/pickup/cash/cancellation modals, review replies and a print-optimised
  packing slip at `/seller/orders/:id/packing_slip`.
- `SellerDashboard` revenue is `sum(total_cents - commission_cents)` for paid,
  shipped, delivered and completed orders.
- Reviews require a completed order, buyer ownership, one per order, a 20–1000
  character body and no words from `Setting blocked_words`. Sellers reply once
  and may edit that reply. `reviews_enabled` hides buyer forms, store review
  panels and listing review sections.
- Notifications live at `/notifications` (unread first, paginated, mark all
  read, per-item read on click) and in a lazy Turbo Frame header bell showing
  the latest eight. `Notification#after_create_commit` replaces the badge over
  `Turbo::StreamsChannel`.
- New settings defaults: `inspection_window_days` 2,
  `auto_complete_after_delivery_days` 2,
  `auto_delivered_after_shipping_days` 14,
  `seller_ship_deadline_days` 3, `support_email` and `blocked_words`.

### Messaging, offers and alerts (Phase 5)

- `Conversation` is one thread per `[listing, buyer, seller]`; seller-only
  threads support store and order entry points. `ConversationStarter` owns the
  rules: chat enabled, no self-messaging, no block in either direction, listing
  visibility, first message and optional first offer.
- The inbox lives at `/inbox` with tabs Chats, Offers, Archived and Blocked
  users. Desktop shows the list and a lazy `turbo-frame#conversation-thread`;
  mobile shows the list and then the thread with a back link. Unread counters
  are atomically incremented by `Message` and reset by `Conversation#
  mark_read_for!`; `Conversation.broadcast_inbox_badge` keeps the header badge
  live over `[user, :inbox]`.
- Messages broadcast `append` to `[conversation, user]` for both participants so
  own/other alignment stays correct. Composer: autosize textarea, Enter sends,
  Shift+Enter newline, 2,000-character maximum, disabled for blocks, deleted
  listings or disabled chat. Day separators use the request locale.
- `MessageSafetyScanner` flags emails, ES/EN phone numbers, IBANs and
  off-platform payment phrases (Bizum, PayPal Friends, Western Union, transfers
  outside the marketplace). The flag is stored on `messages.flagged` and shows a
  translated warning to the recipient without blocking delivery.
- `Message` rate-limits each sender to 30 messages per 10 minutes.
- Offers are `kind: offer` messages with bounds (< listing price, ≥ 50%,
  `accepts_offers`), a 48-hour TTL and `ExpireOffersJob` every ten minutes.
  `OfferResponse` accepts, declines or counters; countering marks the previous
  offer declined and creates a new pending offer. Acceptance writes
  `cart_items.offer_price_cents`/`offer_expires_at` (24 hours); `CartSummary`
  and `Checkout::PlaceOrder` snapshot the offer price on `OrderItem`.
- Blocks are a `Block` row in either direction; the thread header blocks or
  unblocks and the inbox lists blocked users. Reports extend the polymorphic
  `Report` to conversations.
- `MessageNotifier` creates notifications for new messages/offers and emails
  through `MessageMailer` respecting `email_messages`/`email_offers`; message
  emails are throttled to one per conversation and recipient every 15 minutes.
- Publishing a listing enqueues `NotifyFollowersJob` (notification only) and
  `SavedSearchAlertJob` (instant matches, SQL pre-filter by category subtree,
  price and country, then `SavedSearch#matches?`; owner excluded).
  `SavedSearchDigestJob` runs daily at 08:00 Europe/Madrid for saved searches
  with `frequency: daily`, groups up to 20 matches per user and updates
  `last_notified_at`. Both respect `email_saved_search_alerts` and
  `Setting saved_search_alerts_enabled`.
- `PriceDropAlertJob` notifies favourite users when a published price falls and
  emails them when `email_price_drops_favourites` is enabled.
- Saved-search management supports rename, frequency (instant/daily), notify
  toggle, replay and delete. `/account/following` lists followed stores with
  their latest listings. `config.time_zone` is Europe/Madrid while timestamps
  remain stored in UTC.
- New settings default `chat_enabled` already existed; new notification kinds
  are `message_received`, `offer_received`, `offer_accepted`, `offer_declined`,
  `offer_countered`, `followed_store_listing`, `saved_search_match` and
  `price_drop_favourite`.

### Admin panel (Phase 6A)

- All admin routes live under the locale scope at `/:locale/admin`.
  `Admin::BaseController` authenticates, guards `current_user.staff?`, uses the
  dense `admin` layout and exposes the pending moderation badge.
- Admin authorisation uses Pundit policies in `app/policies/admin/`
  (`Admin::ListingPolicy`, `Admin::UserPolicy`, `Admin::StorePolicy` and small
  single-purpose policies). Moderators can moderate listings, users and stores;
  destructive actions (delete listing, ban, role changes, impersonation,
  GDPR soft delete) require an administrator. Unauthorised requests redirect
  back with `errors.not_authorized`.
- `Admin::Auditable` records every admin mutation in `admin_audit_logs` with
  admin, action, polymorphic auditable, a sanitised `saved_changes`/explicit
  changeset (passwords and tokens removed) and the request IP. Listing, user
  and store detail pages show the history; `/admin/audit_logs` filters by
  action, admin and resource.
- The `admin` layout uses a desktop-first sidebar that collapses to icons
  (`admin_sidebar_controller`, persisted in localStorage), slides off-canvas on
  mobile, and a top bar with global search, "View site", theme toggle and the
  signed-in admin.
- Global search (`Admin::GlobalSearch`) queries users (email/username/name),
  listings (title/id), orders (number/id) and stores (name), and renders a
  grouped results page.
- Admin UI kit partials live in `app/views/admin/shared/`: data table with
  whitelisted sortable headers, per-page selector (25/50/100), pagination,
  filter bar, bulk-action bar, status badges, stat cards, empty states, detail
  header with actions dropdown and side meta panel.
- `Admin::Dashboard` caches one payload for two minutes: seven-day KPI trends
  with commission only when positive, 30-day server-rendered inline SVG
  charts (sign-ups line, orders bars, top-10 category bars), latest pending
  listings/orders/users and a health panel (Solid Queue failed and pending
  jobs when the queue tables exist, Active Storage bytes, `pg_database_size`).
  The action plus chrome stays under 40 SQL queries.
- The moderation queue lists `pending_review` listings oldest first with all
  images, a price-versus-category-median warning below 40% (possible scam),
  a `MessageSafetyScanner` description scan, duplicate-image checks by
  Active Storage checksum across different sellers, and seller age/listings/
  sales/rating/rejection/verified context. Actions are approve, approve &
  feature (seven days plus the `featured` label), reject with translated
  preset or free-text reason, bulk approve, and j/k/a/r keyboard shortcuts.
- Approval/rejection goes through `Admin::ListingModeration`, creates a
  notification and enqueues `ListingMailer#approved/#rejected` in the seller
  locale. `Notifier` dispatches listing emails alongside order emails.
- `Admin::ListingQuery` whitelists sort keys and filters by status, category
  subtree, seller, country, price, labels, featured, pending flag and created
  range. `Admin::BulkListingAction` whitelists approve, reject, pause, archive,
  delete, add/remove label, feature and unfeature. `Admin::ListingUpdate`
  validates the game-FPS JSON and keeps only effective spec filter keys.
- User management filters by role, status, confirmation, store, sign-up range
  and country; CSV export (`Admin::UserExport`) reuses the same filters without
  the removed Ruby `csv` default gem. Suspension clears sign-in through
  `User#active_for_authentication?`/`inactive_message` and hides listings via
  the active-owner visibility scope. Bans also archive listings. Role changes
  refuse self-changes and demoting the last administrator. Email confirmation,
  password-reset instructions and GDPR soft delete are audited.
- Impersonation stores the admin id in `session[:impersonator_id]`, signs in as
  the target and shows a public banner with a stop action. Only administrators
  can impersonate and never another administrator; start and stop are audited.
- Store management verifies/unverifies, toggles vacation mode and edits store
  type, company/tax data, policies and counters, linking back to the owner.
- Admin strings live in `admin.<locale>.yml` across all six locales; Devise
  inactive messages are added there (`devise.failure.suspended/banned/deleted`).

### Admin operations: orders, payments, disputes, reports and reviews (Phase 6B)

- `Admin::OrdersController` lists every order with `Admin::OrderQuery`
  (status, fulfilment, payment method, seller/store, buyer email, created and
  total ranges, late-shipment and refund-needed flags), whitelisted sorting,
  a totals row (count, GMV, commission) and CSV export through
  `Admin::OrderExport` (manual CSV because Ruby 4 removed the default `csv`
  gem).
- Order detail shows buyer, seller/store, item snapshots with listing links,
  shipping address, payment and refund references, commission/net, the
  `OrderEvent` timeline, the related `Conversation`, internal `OrderNote`
  records and the audit history.
- Nested RESTful resources: `payment` (bank-transfer reconciliation, requires a
  reference, audited), `cancellation` (reason, stock restored through
  `Order#cancel!`), `refund` (administrator only, stores `refund_reference`),
  `email` (buyer/seller resend) and `notes`. `Order#resolve_dispute!` accepts an
  optional resolution message and `Order#refund!` accepts a reference.
- `Admin::PaymentsController#index` lists pending bank-transfer orders oldest
  first with the payment deadline and a quick mark-paid form.
  `Admin::BulkPaymentsController#create` delegates to `Admin::BulkPayment`,
  which parses one order number per line and renders a paid / not found /
  wrong-status summary.
- `Admin::DisputesController` lists disputed orders oldest first with age and
  reason. Detail combines the order summary, dispute reason/details/photos,
  read-only conversation messages, timeline, internal notes and the resolution
  form. `Admin::DisputeResolution` calls `Order#resolve_dispute!`; refunds
  require an administrator, releases are available to moderators.
  `OrderNotifier` sends the resolution message to both parties as an in-app
  notification and locale-aware `OrderMailer#dispute_resolved_buyer/#_seller`
  email, respecting email preferences.
- `Admin::ReportsController` filters by status, reason and reportable type and
  shows counts per status. `Admin::ReportResolution` resolves with an optional
  action (pause listing, suspend user through `Admin::UserModeration`, unpublish
  review) or dismisses, notifies the reporter through `Notifier` and writes an
  audit entry. Bulk dismiss goes through `Admin::BulkReportActionsController`.
- `Admin::ReviewsController` filters rating, publication, store, reply presence
  and created range. Unpublish/publish and reply visibility are staff actions;
  deletion is administrator-only. Review callbacks recalculate the store rating
  after unpublish. `reviews.seller_reply_visible` hides a seller reply from
  public store, listing and order views while keeping it visible to the seller.
- Dashboard dispute, report and pending-payment stat cards link to their
  screens. `Admin::SidebarCounts` caches open disputes, open reports and pending
  payments for one minute; the dashboard reuses its own cached aggregates to
  avoid extra queries.
- New schema: `order_notes` (`order_id`, `author_id`, `body`), `orders
  .refund_reference` and `reviews.seller_reply_visible`.

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
app/controllers/seller/orders_controller.rb seller sales tabs/show
app/controllers/seller/orders/            shipments, pickups, payments,
                                          cancellations, packing slips
app/controllers/seller/order_exports_controller.rb CSV sales export
app/controllers/seller/review_replies_controller.rb review replies
app/controllers/orders/delivery_confirmations_controller.rb
app/controllers/orders/disputes_controller.rb
app/controllers/orders/reviews_controller.rb
app/controllers/notifications_controller.rb   list, mark one read
app/controllers/notifications/read_alls_controller.rb
app/controllers/conversations_controller.rb   inbox tabs, thread, start conversation
app/controllers/conversations/                messages, offers, reads, archives, read all
app/controllers/messages/offer_responses_controller.rb
app/controllers/blocks_controller.rb          block/unblock users
app/controllers/account/following_controller.rb
app/services/notifier.rb                    notification + preference email
app/services/message_notifier.rb            message/offer notifications + throttled email
app/services/message_safety_scanner.rb      contact and off-platform payment detection
app/services/conversation_starter.rb        chat creation rules and first message
app/services/offer_response.rb              accept/decline/counter + reserved cart price
app/mailers/message_mailer.rb               message and offer emails
app/mailers/saved_search_mailer.rb          instant match and daily digest emails
app/mailers/favourite_mailer.rb             favourite price-drop email
app/jobs/notify_followers_job.rb
app/jobs/saved_search_alert_job.rb
app/jobs/saved_search_digest_job.rb
app/jobs/price_drop_alert_job.rb
app/jobs/expire_offers_job.rb
app/views/conversations/                   inbox list, thread, composer, offer form
app/views/messages/_message.html.erb       bubble, offer card, safety and receipts
app/views/messaging/_inbox_badge.html.erb  live header unread total
app/views/account/following/               followed stores + latest listings
app/services/order_notifier.rb              order event fan-out
app/services/profanity_filter.rb            blocked words
app/services/seller_order_export.rb         filtered CSV
app/jobs/auto_deliver_orders_job.rb
app/jobs/auto_complete_orders_job.rb
app/jobs/late_shipment_reminder_job.rb
app/views/seller/orders/                   index, show, packing slip
app/views/notifications/                   index, menu, badge
app/views/layouts/packing_slip.html.erb    printable layout
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
app/controllers/admin/base_controller.rb        auth, staff guard, admin layout,
                                                Pundit + audit helpers
app/controllers/admin/dashboard_controller.rb   cached KPIs, charts, health
app/controllers/admin/moderation_queue_controller.rb
app/controllers/admin/listings_controller.rb    listing table, detail, edit, delete
app/controllers/admin/listing_approvals_controller.rb
app/controllers/admin/listing_rejections_controller.rb
app/controllers/admin/bulk_listing_actions_controller.rb
app/controllers/admin/users_controller.rb       user directory, detail, edit
app/controllers/admin/{user_suspensions,user_bans,user_roles}_controller.rb
app/controllers/admin/{user_confirmations,user_password_resets,user_deletions}_controller.rb
app/controllers/admin/{impersonations,user_exports}_controller.rb
app/controllers/admin/stores_controller.rb      store table, detail, edit
app/controllers/admin/{store_verifications,store_vacations}_controller.rb
app/controllers/admin/{audit_logs,search,placeholders}_controller.rb
app/controllers/admin/orders_controller.rb         order table, detail, timeline
app/controllers/admin/order_{payments,cancellations,refunds,emails,notes,exports}_controller.rb
                                                   nested order resources + CSV
app/controllers/admin/payments_controller.rb       bank-transfer reconciliation
app/controllers/admin/bulk_payments_controller.rb  pasted order-number summary
app/controllers/admin/disputes_controller.rb       dispute queue and detail
app/controllers/admin/dispute_resolutions_controller.rb
app/controllers/admin/reports_controller.rb        report queue, detail, resolve
app/controllers/admin/bulk_report_actions_controller.rb
app/controllers/admin/reviews_controller.rb        review moderation
app/controllers/concerns/admin/auditable.rb     admin mutation audit writer
app/policies/admin/                             staff and admin-only policies
app/services/admin/dashboard.rb                 cached dashboard aggregates
app/services/admin/listing_query.rb             whitelisted filters/sorting
app/services/admin/listing_moderation.rb        approve, reject, feature + email
app/services/admin/listing_flags.rb             median, safety scan, duplicates
app/services/admin/listing_update.rb            admin listing form writer
app/services/admin/bulk_listing_action.rb       whitelisted bulk mutations
app/services/admin/{user_query,user_export,user_moderation}.rb
app/services/admin/{store_query,global_search}.rb
app/services/admin/order_query.rb                filtered/sorted order relation
app/services/admin/{order_export,bulk_payment}.rb
app/services/admin/{dispute_query,dispute_resolution}.rb
app/services/admin/{report_query,report_resolution}.rb
app/services/admin/{review_query,sidebar_counts}.rb
app/models/order_note.rb                         internal staff notes
app/mailers/listing_mailer.rb                   approved/rejected seller emails
app/helpers/admin_helper.rb                     nav, badges, charts, audit labels
app/views/layouts/admin.html.erb                sidebar + top bar shell
app/views/admin/shared/                         table, filter, bulk, stats, meta kit
app/views/admin/{dashboard,moderation_queue,listings,users,stores}/**
app/views/admin/{orders,payments,bulk_payments,disputes,reports,reviews}/**
app/views/admin/{audit_logs,search,placeholders}/
app/javascript/controllers/admin_sidebar_controller.js
app/javascript/controllers/admin_queue_controller.js
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
test/integration/admin_{access,panel,moderation,users}_test.rb
test/integration/admin_{orders,disputes,reports,reviews}_test.rb
test/services/admin/sidebar_counts_test.rb
test/system/admin_moderation_flow_test.rb
test/seeds_test.rb
```

## Open items for later phases

- Admin screens for categories, filters, legal pages, games, newsletter and
  settings are placeholders until phase 6C.
- Refunds are recorded manually with a reference; no payment-provider refund
  API is called yet.
- Admin two-factor authentication is not implemented; Devise lockable already
  throttles failed sign-ins. Decide whether staff 2FA is required before
  phase 6C.
- Impersonation is session-based and audited; there is no automatic timeout.
- Admin dashboards and moderation flags are heuristic (price median and image
  checksum reuse), not fraud detection.
- Seller dashboard performance is cached for five minutes; order-level events
  do not invalidate it immediately.
- Order lifecycle emails to admins rely on `Setting.support_email`; there is no
  staff inbox UI yet.
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
- No typing indicator in conversations (explicitly out of scope).
- Message safety detection is heuristic; moderation review is still manual.
