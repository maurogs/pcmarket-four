# PCMarket — Project Context

## Status

Phase 1 complete: foundation, localisation, full data model, policies, seeds,
fixtures and tests. No marketplace UI beyond the placeholder home page.

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
- All routes except `/up` (and future `/api`, `/sitemap.xml`, `/robots.txt`) are
  wrapped in `scope "(:locale)", locale: /es|en|fr|de|it|pt/`.
- `ApplicationController#switch_locale` validates `params[:locale]` and wraps
  each request in `I18n.with_locale`.
- Devise OmniAuth callbacks live outside the locale scope because Devise does
  not support OmniAuth callbacks under a dynamic segment.
- Locale files are split by domain (`models`, `home`, `errors`, `common`,
  `countries`); every key exists in all six languages.
- English is British English (favourite, colour, authorised).

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
  enabled country.
- Slugs: FriendlyId on `Store` (name), `Category` (English name) and `Listing`
  (title, with history through `friendly_id_slugs`).
- Reviews recalculate `stores.rating_avg`/`reviews_count` in `after_commit`.
- Orders compute subtotal, commission (only when enabled) and total in
  `Order#compute_totals!`.
- Favourites and follows use counter caches.

### Authorisation

- `ApplicationController` includes `Pundit::Authorization`; unauthorised
  requests redirect back with `errors.not_authorized`.
- `ListingPolicy` lets owners edit/delete their listings and moderators/admins
  approve or reject. `ListingPolicy::Scope` hides non-visible listings from the
  public.

## Code map

```
app/controllers/application_controller.rb   locale switching, Pundit rescue
app/controllers/home_controller.rb          placeholder home
app/controllers/users/omniauth_callbacks_controller.rb
app/models/                                30 domain models
app/policies/                              ApplicationPolicy, ListingPolicy
config/application.rb                      I18n configuration
config/routes.rb                           locale scope, Devise, root
config/initializers/devise.rb              Devise + conditional Google OAuth
config/initializers/rack_attack.rb         request throttling
config/locales/                            models/home/errors/common/countries
db/migrate/                                reversible migrations incl. extensions
db/seeds.rb                                idempotent reference + demo data
test/fixtures/                             valid fixture per model
test/models/                               model tests
test/integration/home_test.rb              locale routing test
```

## Open items for later phases

- Authentication views, registration and profile management.
- Listing creation/edit forms, image uploads and moderation screens.
- Search and filter UI (filter definitions and categories are ready).
- Favourites, follows, saved-search alerts and conversations UI.
- Cart, checkout, orders and reviews UI.
- Seller stores, sell-to-us flow and admin dashboard.
- API endpoints, sitemap and robots.txt.
- Mailer templates and background jobs for notifications.
