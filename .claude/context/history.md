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
