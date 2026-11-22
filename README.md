# PCMarket

PCMarket is a marketplace for new and second-hand technology: gaming PCs,
workstations, components, peripherals, laptops, phones, tablets, consoles and
accessories. Spain only at launch.

This repository contains **Phase 8**: the complete marketplace with discovery,
listing creation, checkout and payments, order lifecycle, messaging, admin
operations, legal and help content, the PC Finder, and a versioned JSON API.
Phase 8 adds a realistic, image-backed demo data set.

## Stack

- Ruby 4.0.9
- Rails 8.1 (Hotwire: Turbo + Stimulus, import maps, Propshaft)
- PostgreSQL 16
- Tailwind CSS 4 via `tailwindcss-rails`
- Devise (database authentication + Google OAuth), Pundit, Pagy, pg_search,
  FriendlyId, Ancestry, rack-attack, meta-tags

## Requirements

- Ruby 4.0.9 (see `.ruby-version`)
- PostgreSQL running locally
- Bundler 4+

## Setup

```bash
bundle install
bin/rails db:create db:migrate
bin/rails db:seed
```

`bin/rails db:seed` is idempotent and loads `db/seeds.rb`, which in turn loads
the files in `db/seeds/` in dependency order:

1. `settings.rb` — typed setting defaults.
2. `countries.rb` — ES (enabled), FR, GB, DE, IT, PT.
3. `regions.rb` — 52 Spanish provinces and autonomous cities, French regions,
   UK nations, German Länder, Italian regions and Portuguese districts.
4. `categories.rb` — the full two-level category tree with English slugs and
   names in all six languages.
5. `filters.rb` — filter definitions, translated options and category
   assignments.
6. `games.rb` — supported game catalogue.
7. `legal_pages.rb` — seeded legal pages.
8. `help_articles.rb` — help-centre articles.
9. `buyback_prices.rb` — GPU and CPU trade-in catalogue.
10. `demo.rb` — the full development demo data set.

The demo seed creates an administrator (`admin@pcmarket.test`), a moderator
(`moderator@pcmarket.test`), professional stores, individual sellers, buyers,
listings, conversations, orders, reviews, notifications and marketing records.
Every demo account uses the password `Password123!` and demo users are tagged
with the `@demo.pcmarket.test` email domain. The seed is idempotent.

`bin/rails db:reset` rebuilds the database from scratch, loads the schema and
runs the seeds (including demo data in development).

## Demo data and images

```bash
bin/rails demo:images   # download and cache openly licensed photos
bin/rails demo:seed     # idempotent demo seed
bin/rails demo:reset    # delete demo records and their blobs, then reseed
```

`demo:images` stores resized JPEGs under `storage/demo_images/` (gitignored) and
writes the committed attribution manifest at `db/seeds/demo/image_manifest.json`.
The app serves credits at `/:locale/credits`, linked from the footer.

Openverse is used without a key. The other providers are optional and are only
called when their key is present:

```bash
export UNSPLASH_ACCESS_KEY=...
export PEXELS_API_KEY=...
export PIXABAY_API_KEY=...
```

`DEMO_SCALE` (for example `0.05`) creates a smaller seed for smoke tests;
`DEMO_IMAGES_PER_QUERY` overrides the default target of 10 photos per query.
`DEMO_IMAGES=0` skips images and uses the placeholder illustration, which is
also the automatic fallback when the network or the cached library is
unavailable.

## Localisation

The app is available in Spanish, English, French, German, Italian and
Portuguese:

- Default locale: `es`
- Fallbacks: `es`, then `en`
- Every locale is reachable through a prefix: `/en`, `/fr`, `/de`, `/it`, `/pt`
- Locale files live in `config/locales/<domain>.<locale>.yml`
- Every user-facing string is translated; `test/i18n/locale_parity_test.rb`
  fails when a Spanish key is missing from another locale
- English uses British spelling (colour, favourite, authorised, centre)

The language switcher in the footer and mobile drawer keeps the current path
and query string when changing locale.

## Design system

- Brand colour: deep teal, exposed as `--color-brand-50..950` in
  `app/assets/tailwind/application.css` (primary `brand-700` `#0F766E`).
- Purchase calls to action use warm amber (`accent-500` `#F59E0B`).
- Neutrals are slate in light mode and zinc in dark mode.
- Headings use Space Grotesk (600/700), body text uses Inter (400/500/600),
  loaded from Google Fonts with `display=swap`.
- Cards use a 12 px radius; buttons, chips and badges are pills.
- Dark mode uses the `.dark` class on `<html>`, persists to localStorage and a
  cookie, follows `prefers-color-scheme` by default and is applied by an inline
  head script to avoid a flash.
- Icons are vendored Lucide SVGs in `app/assets/images/icons/` and rendered by
  the `icon(name, class:)` helper. There is no icon font and no external icon
  script.

Reusable UI lives in `app/views/shared/` (cards, badges, chips, price tags,
star ratings, empty states, toasts, modal, dropdown, tabs, accordion, skeleton
loader and pagination) plus helper classes in `app/helpers/application_helper.rb`.

## SEO and security

- `display_meta_tags` sets the site title, description, canonical URL,
  hreflang alternates for all locales plus `x-default`, Open Graph and Twitter
  card metadata.
- JSON-LD for `Organization` and `WebSite` (with `SearchAction`) is emitted once
  per page.
- `GET /robots.txt` allows crawling in production, blocks private paths and
  filtered search URLs, and advertises the sitemap. Non-production environments
  disallow everything.
- `GET /sitemap.xml` lists home, static pages, categories, visible listings,
  stores and legal pages with `xhtml:link` alternates. It is cached for one
  hour and splits into a sitemap index after 45,000 URLs.
- A strict nonce-based CSP allows self-hosted assets, Google Fonts, data/blob
  images and the import map. `Permissions-Policy` and `Referrer-Policy`
  headers are set in `config/initializers/security_headers.rb`.
- Cookies are only used for necessary functionality. Analytics and marketing
  consent choices are stored in `cookie_consent` for six months; no third-party
  script is loaded by default.

## Running the app

```bash
bin/dev
```

`bin/dev` starts the Rails server and the Tailwind watcher through
`Procfile.dev`. The app is available at <http://localhost:3000>.

Development uses the in-memory cache store. To enable controller and fragment
caching locally, run:

```bash
bin/rails dev:cache
```

## Google OAuth

Google sign-in is optional. Register the provider only when both environment
variables are present:

```bash
export GOOGLE_CLIENT_ID=your-client-id
export GOOGLE_CLIENT_SECRET=your-client-secret
```

The callback URL is `/users/auth/google_oauth2/callback`.

The JSON API verifies Google ID tokens against an explicit allowlist. Set
`GOOGLE_CLIENT_IDS` to the comma-separated web, iOS and Android client IDs;
`GOOGLE_CLIENT_ID` is still accepted for backwards compatibility. If neither
variable is set, `POST /api/v1/auth/google` is disabled and returns
`503 google_sign_in_unavailable`.

## Tests and quality checks

```bash
bin/rails test
bin/rubocop
```

The suite covers the data model, settings caching, listing workflow, search,
categories, orders, reviews, counter caches, saved searches, seed idempotency,
locale parity, home rendering in every locale, hreflang and JSON-LD output,
robots.txt, sitemap.xml, search suggestions, navigation and feature flags,
cookie consent, newsletter subscription/confirmation and admin access control.

## Useful commands

```bash
bin/rails db:drop db:create db:migrate   # rebuild the development database
bin/rails db:seed                        # seed reference + demo data
bin/rails demo:images                    # refresh the image cache and manifest
bin/rails demo:reset                     # recreate demo data from scratch
bin/rails routes                         # inspect routes
bin/rails tailwindcss:build              # compile Tailwind once
```

## Project documentation

- `CLAUDE.md`: working rules for this repository
- `.claude/context/project.md`: architecture, decisions and code map
- `.claude/context/history.md`: change log
