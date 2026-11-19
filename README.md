# PCMarket

A multi-country tech marketplace built with Ruby on Rails 8.1. Buyers and
sellers meet in localized markets (Spain first) with classifieds, fixed-price
listings and an eventual auction system.

This repository is currently on **Phase 0 — Foundation**: gems, internationalization,
multi-country settings/feature flags, the Tailwind v4 design system, Devise
authentication and security configuration. The catalog, listings and ordering
flows come in later phases.

## Tech stack

| Concern          | Choice                                              |
| ---------------- | --------------------------------------------------- |
| Framework        | Rails 8.1 (Propshaft, Solid Queue/Cache/Cable)      |
| Ruby             | 4.0 (rbenv)                                         |
| Database         | PostgreSQL                                          |
| Frontend         | Tailwind CSS v4 + Hotwire (Turbo/Stimulus, importmap) |
| Auth             | Devise (+ OmniAuth Google, gated on env vars)       |
| Authorization    | Pundit                                              |
| Search (later)   | pg_search                                           |
| i18n             | Rails I18n + rails-i18n + devise-i18n, 6 locales    |

## Requirements

- Ruby 4.0 (see `.ruby-version`), Bundler 4
- PostgreSQL, with the databases configured in `config/database.yml`
- Linux x86_64 (for the native Tailwind binary; see *Bundler platform note* below)

## Getting started

```bash
bundle install
bin/rails db:prepare     # create, migrate and seed (countries + settings)
bin/dev                  # web + tailwind watcher on http://localhost:3000
```

Seed data: 6 countries (only Spain enabled), 18 settings/feature flags, and
the catalog reference data — 45 categories, 35 filter definitions with 223
filter options, category→filter assignments, product labels and seller tags.
All seed files (`db/seeds/*.rb`, loaded in order by `db/seeds.rb`) are
idempotent: re-running `bin/rails db:seed` updates in place and preserves
admin edits. In development it also creates a handful of sample users.

### Demo data (development only)

For a populated storefront while developing, run the opt-in demo seed:

```bash
DEMO=1 bin/rails db:seed
```

It loads `db/seeds/development/demo.rb` (development environment only, never
in test or production) and creates ~30 Spanish demo users (`@demo.example.com`
emails), 8 stores and ~240 published listings built from the real catalog —
including discounts, featured slots, seller tags and sold history — so the
mega menu, home page, search filters and store pages all have content. The run
is skipped once demo listings exist, so repeated `db:seed` runs are cheap.

### Bundler platform note

`tailwindcss-ruby` ships precompiled binaries per platform. If your shell
exports `BUNDLE_FORCE_RUBY_PLATFORM=true`, bundler skips them and
`bin/rails tailwindcss:build` fails. Either unset it
(`unset BUNDLE_FORCE_RUBY_PLATFORM`) or keep it out of your environment;
`bin/dev` unsets it for you. The lock file includes the `x86_64-linux`
platform.

## Internationalization

- Available locales: `en, es, fr, de, it, pt` (default: `es`, fallback: `en`).
- Locale resolution order: **URL prefix → signed cookie → Accept-Language → default**.
- All localized routes live under an optional prefix (`/fr/pages/about`, `/de`…),
  see `config/routes.rb` and `LocaleConcern`.
- One file per locale in `config/locales/<locale>.yml`. **Every locale file must
  define exactly the same keys** — `test/i18n_keys_test.rb` enforces this.
- Countries carry a `default_locale`; user preferred locale is stored on `User#locale`.

Exception: OmniAuth callbacks are routed *outside* the locale scope — Devise
cannot scope them under a dynamic segment.

## Multi-country & feature flags

- `Country` (`app/models/country.rb`): ISO code, currency, VAT rate, enabled
  flag; only launched markets are enabled. Addressed by code (`/c/ES` style
  helpers not built yet).
- `Setting` (`app/models/setting.rb`): typed key/value store
  (`string`, `boolean`, `integer`, `float`, `json` — `json` is real JSONB).
- `AppSettings` (`app/services/app_settings.rb`): cached reads
  (`get / enabled? / localized / all`) backed by `Rails.cache`, invalidated on
  save/touch/destroy. `localized` reads `{ "es": …, "en": … }` values in the
  current locale.

Feature flags already wired: `sell_to_us_enabled`, `offers_enabled`,
`auctions_enabled`, `reviews_enabled`, `maintenance_mode`, etc.

## Design system

Tailwind v4 with CSS-first configuration in `app/assets/tailwind/application.css`:

- Warm cream surfaces, primary indigo ramp, Fraunces (display serif) +
  Inter (UI sans), all as CSS custom properties with light/dark variants
  (`@custom-variant dark`).
- Component utilities: `btn`/`btn-primary`/`btn-secondary`/`btn-ghost`,
  `input-field`, `card`, `section-title`.
- Fonts are self-hosted (Google variable fonts, latin + latin-ext) in
  `public/fonts/`, referenced from `app/assets/tailwind/fonts.css` — this
  keeps the strict CSP (`font-src 'self'`) intact.
- Theme toggle (system/light/dark) persisted in a cookie, no-flash bootstrap
  in the layout; Stimulus controllers for dropdowns, mobile drawer and toasts.

## Security

- Strict Content-Security-Policy (everything `'self'`, nonces for inline
  script/style) enforced in staging and report-only in development.
- `rack-attack` throttles (300 req/5 min/IP, 5 logins/minute) with an
  allow-list for local.
- Devise: lockable (10 attempts), reactivatable/confirmable, sanitized params;
  Google OAuth only when `GOOGLE_CLIENT_ID`/`GOOGLE_CLIENT_SECRET` are set
  (the sign-in button hides itself accordingly).
- Cookie-based persistence for locale and selected country (signed).

## Testing & linting

```bash
bin/rails test           # minitest suite (i18n parity, locale routing, flags, cache)
bin/rubocop              # standardrb ruleset
bin/rails tailwindcss:build
```

## Troubleshooting

**`tailwindcss-ruby` binary not found** — if a Rails command fails with an error
about the Tailwind CSS executable (e.g. when running under rbenv), point the
gem at the installed binary:

```bash
export TAILWINDCSS_INSTALL_DIR="$HOME/.rbenv/versions/$(cat .ruby-version)/lib/ruby/gems/$(cat .ruby-version).0/gems/tailwindcss-ruby-<version>-x86_64-linux-gnu/exe/x86_64-linux-gnu"
```

Adjust the gem version in the path to the one in `Gemfile.lock`. The export
only needs to be in the shell running Rails commands (`bin/rails`, `bin/dev`).

## Layout cheatsheet

```
app/
  assets/tailwind/          # Tailwind v4 input CSS + fonts.css
  controllers/concerns/     # locale_concern.rb (locale + country resolution)
  javascript/controllers/   # theme_toggle, dropdown, drawer, toast
  models/                   # country, setting, user, current, category,
  |                         # filter_definition/option, store, listing (AASM)
  policies/                 # application_policy (Pundit base)
  services/                 # app_settings.rb, listings/search.rb,
  |                         # stores/*, categories/*
  views/{devise,home,pages,searches,sell_to_us,shared}/
config/locales/             # en/es/fr/de/it/pt .yml — keys must match exactly
db/                         # countries, settings, devise users, catalog seeds;
  |                         # idempotent seeds; structure.sql (schema :sql)
```

## Roadmap (phases)

0. **Foundation** — i18n, countries, flags, design system, auth.
1. Catalog: categories, listings, search, seller profiles.
   1a. **Done** — data model: category tree, filter definitions/options,
       stores, listings with AASM moderation workflow and a trigger-maintained
       weighted `tsvector` search column (unaccent + custom text search
       config), `Listings::Search` service (filters, facets, pagination).
   1b. Storefront: category/browse pages, listing detail, seller dashboard.
2. Ordering: carts or direct checkout, Stripe payments, shipping.
3. Auctions, offers/negotiation, reviews.
4. Seller tools, moderation, SEO growth (sitemap already in place).
