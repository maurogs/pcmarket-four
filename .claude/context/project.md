# PCMarket — Project Context

## Status

Phase 2 complete: full taxonomy seeds, design system, global layout, home page
and SEO infrastructure. Listing, store, cart, checkout and account pages have
localised routes and placeholder screens ready for Phase 3.

## Stack

- Ruby 4.0.9, Rails 8.1.4, PostgreSQL 16
- Hotwire (Turbo, Stimulus), import maps, Propshaft, Tailwind CSS 4
- Devise 5 (database authenticatable, registerable, recoverable, rememberable,
  validatable, confirmable, trackable, lockable, omniauthable)
- Pundit (authorisation), Pagy 9 (pagination)
- pg_search (tsearch + trigram), FriendlyId, Ancestry
- rack-attack, meta-tags
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
  `pages`, `newsletter`, `errors`, `common`, `countries`); every key exists in
  all six languages. `test/i18n/locale_parity_test.rb` enforces parity.
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
  `Order#compute_totals!`.
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
app/controllers/application_controller.rb   locale, meta tags, menu, staff guard
app/controllers/home_controller.rb          home feed
app/controllers/listings_controller.rb      index/show + placeholders, Pagy
app/controllers/categories_controller.rb    category path resolution
app/controllers/search_suggestions_controller.rb
app/controllers/seo_controller.rb           robots.txt + sitemap.xml
app/controllers/newsletter_subscribers_controller.rb
app/controllers/{cart,favorites,conversations,orders,account,pc_finder,pages,legal_pages,sell_offers}_controller.rb
app/controllers/admin/dashboard_controller.rb
app/controllers/seller/dashboard_controller.rb
app/services/menu_builder.rb                cached mega-menu payload
app/services/home_feed.rb                   home queries
app/services/search_suggestions.rb          listing/category/store suggestions
app/services/newsletter_subscription.rb     idempotent subscription statuses
app/services/sitemap_builder.rb             XML sitemap + index
app/helpers/application_helper.rb           icons, UI classes, money, consent, JSON-LD
app/views/layouts/application.html.erb      global head, header, main, footer
app/views/shared/                           layout partials and UI primitives
app/views/listings/_card.html.erb           shared listing card
app/views/home/index.html.erb               home sections
app/assets/tailwind/application.css         design tokens and base styles
app/assets/images/icons/                    vendored Lucide SVGs
app/javascript/controllers/                 theme, drawer, mega-menu, autocomplete,
                                            carousel, dropdown, modal, tabs, toasts,
                                            cookie consent, scroll rows, back-to-top
config/routes.rb                            locale scope + SEO endpoints
config/initializers/content_security_policy.rb
config/initializers/security_headers.rb
config/locales/                             six-language UI strings
db/seeds.rb                                 loader
db/seeds/*.rb                               taxonomy and reference data
test/integration/                           home, SEO, suggestions, newsletter, admin
test/i18n/locale_parity_test.rb
test/seeds_test.rb
```

## Open items for later phases

- Full listing search with filters, sorting, pagination controls and saved
  search alerts.
- Listing detail, store pages, listing creation/edit forms and image uploads.
- Authentication screens styling and profile management.
- Cart, checkout, orders and reviews workflows.
- Seller dashboard, sell-to-us flow and admin moderation screens.
- Conversations, notifications and offers.
- Newsletter double opt-in templates can be styled further; delivery currently
  uses `deliver_later`.
- Background jobs for saved-search alerts and notifications.
- Real social profile URLs and legal copy per locale.
- API endpoints.
