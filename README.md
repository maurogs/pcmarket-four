# PCMarket

PCMarket is a marketplace for new and second-hand technology: PCs, graphics
cards, components, peripherals, laptops, phones, tablets and consoles.

This repository currently contains **Phase 1**: the application foundation and
the complete data model. The only user-facing page is a localised placeholder
home page.

## Stack

- Ruby 4.0.9
- Rails 8.1 (Hotwire: Turbo + Stimulus, import maps, Propshaft)
- PostgreSQL 16
- Tailwind CSS 4 via `tailwindcss-rails`
- Devise (database authentication + Google OAuth), Pundit, Pagy, pg_search,
  FriendlyId, Ancestry, rack-attack

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

`bin/rails db:seed` is idempotent. It creates the settings defaults, the
enabled countries, Spanish regions, the category tree, filter definitions,
games, legal pages and, outside production, an administrator account:

- Email: `admin@pcmarket.test`
- Password: `Password123!`

In development it also creates a demo seller (`seller@pcmarket.test`) with a
store and one published listing.

## Running the app

```bash
bin/dev
```

`bin/dev` starts the Rails server and the Tailwind watcher through
`Procfile.dev`. The app is available at <http://localhost:3000>.

## Localisation

The app is available in Spanish, English, French, German, Italian and
Portuguese:

- Default locale: `es`
- Fallbacks: `es`, then `en`
- Every locale is reachable through a prefix: `/en`, `/fr`, `/de`, `/it`, `/pt`
- Locale files live in `config/locales/<domain>.<locale>.yml`; model names,
  attribute names, enum labels and custom validation messages are kept in sync
  across all six languages.

English strings use British spelling (colour, favourite, authorised, centre).

## Google OAuth

Google sign-in is optional. Register the provider only when both environment
variables are present:

```bash
export GOOGLE_CLIENT_ID=your-client-id
export GOOGLE_CLIENT_SECRET=your-client-secret
```

The callback URL is `/users/auth/google_oauth2/callback`.

## Tests and quality checks

```bash
bin/rails test
bin/rubocop
```

The test suite covers the data model, settings caching, listing workflow,
search, categories, orders, reviews, counter caches, saved searches and locale
routing, using Minitest with fixtures.

## Useful commands

```bash
bin/rails db:drop db:create db:migrate   # rebuild the development database
bin/rails db:seed                        # seed reference data
bin/rails routes                         # inspect routes
bin/rails tailwindcss:build              # compile Tailwind once
```

## Project documentation

- `CLAUDE.md`: working rules for this repository
- `.claude/context/project.md`: architecture, decisions and code map
- `.claude/context/history.md`: change log
