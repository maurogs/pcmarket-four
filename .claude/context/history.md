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
