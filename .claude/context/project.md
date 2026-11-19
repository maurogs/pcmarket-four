# PCMarket — Project Context

_Last updated: 2026-11-19 (Phase 0 foundation complete, uncommitted)_

## What this is

Multi-country tech marketplace (classifieds → listings → auctions) on
Rails 8.1 / Ruby 4.0 / PostgreSQL / Tailwind v4 / Hotwire. Spain first;
FR/GB/DE/IT/PT seeded but disabled.

## Key decisions

- **Locales**: `[:en, :es, :fr, :de, :it, :pt]`, default `:es`; fallbacks map
  every non-es locale straight to `:en` (`config.i18n.fallbacks`). Locale
  resolution: param > signed cookie (`pcmarket_locale`) > Accept-Language >
  default, in `LocaleConcern`. Routes wrapped in `scope "(:locale)"`.
- **One locale file per language** (`config/locales/<locale>.yml`) containing
  app strings **and** a small custom `devise:` subtree; standard Devise strings
  come from the devise-i18n gem (`devise.en.yml` was deleted). Parity enforced
  by `test/i18n_keys_test.rb`.
- **OmniAuth routes live outside the locale scope** — Devise rejects
  omniauth callbacks under dynamic segments. `devise_for … only: :omniauth_callbacks`
  sits above the scope, the rest inside.
- **Countries**: ISO `code` is the PK-ish lookup (`to_param`), i18n `name_key`,
  `default_locale`, `enabled`, `launched_at` required when enabled. Current
  country = signed cookie > enabled country matching locale > first enabled
  (set in ApplicationController into `Current`).
- **Settings/feature flags**: `Setting` model (jsonb `value`, `value_type`
  casting via `typed_value`) + `AppSettings` service on `Rails.cache`
  (`app_settings/<key>`, `app_settings/all`). Cache invalidation uses
  `after_save/touch/destroy` (NOT `after_commit` — that never fires under
  transactional fixtures).
- **Fonts self-hosted** (Fraunces + Inter variable woff2, latin + latin-ext) in
  `public/fonts/`, `@font-face` in `app/assets/tailwind/fonts.css`; absolute
  `/fonts/...` URLs because neither Tailwind nor Propshaft rewrites relative
  URLs out of `app/assets/tailwind`. CSP stays `'self'`-only.
- **CSP nonces** use a random generator (`SecureRandom`) — `session.id` is nil
  for anonymous requests and produced empty nonces.
- **Google OAuth env-gated**: `GOOGLE_CLIENT_ID/SECRET`; helper
  `google_oauth_enabled?` hides the button when unset.
- **Bundler quirk**: user's `~/.bashrc` exports `BUNDLE_FORCE_RUBY_PLATFORM=true`
  (left untouched); `bin/dev` unsets it and the lock file has `x86_64-linux`
  so tailwindcss-ruby's native binary installs. A broken `mirror.https://`
  bundler config was removed earlier (was breaking `bundle install`).
- Devise: confirmable + lockable (10 attempts, 1h unlock), username optional
  (auto-generated from email/name), `User.from_omniauth` auto-confirms.

## Code map (Phase 0)

- `app/controllers/concerns/locale_concern.rb` — locale + cookie logic.
- `app/controllers/application_controller.rb` — Pundit base, `Current.user/country`,
  locale/country resolution, devise param sanitizer, CSRF except json.
- `app/controllers/{home,pages,searches,sell_to_us,newsletter_subscribers}_controller.rb`
  (+ `users/omniauth_callbacks_controller.rb`). Pages use a `PAGES` allowlist;
  sell-to-us is flag-gated via `AppSettings.enabled?`.
- `app/models/` — `country`, `setting`, `user`, `current`.
- `app/services/app_settings.rb` — cached typed/localized reads.
- `app/policies/application_policy.rb` — Pundit scaffold.
- `app/helpers/` — `icon_helper` (inline SVG set), `locale_helper`, app helper
  (nav taxonomy `nav_categories`, `category_label/path`, `google_oauth_enabled?`).
- Views: `layouts/application` + `shared/` (announcement bar, header/mega-nav,
  mobile drawer, footer + newsletter, toasts), restyled `devise/`, `home/`,
  `pages/`, `searches/`, `sell_to_us/`.
- `app/javascript/controllers/` — `theme_toggle`, `dropdown`, `drawer`, `toast`.
- `app/assets/tailwind/application.css` — design tokens + `btn`/`input-field`/
  `card`/`section-title` utilities; `fonts.css` imported.
- Initializers: `devise` (mailer sender from ENV, lockable, google omniauth),
  `rack_attack`, `content_security_policy` (strict, report-only in dev),
  `omniauth` (POST request phase), `bullet` (dev, off via env).
- `config/sitemap.rb` + `GET /sitemaps` controller-less redirect → per-locale sitemap.
- Seeds are idempotent (`seed_record` upsert by natural key).

## Testing

- `bin/rails test` — 44 tests green: i18n parity, root renders in all 6
  locales (html lang), cookie/Accept-Language negotiation, 404 for `/xx`,
  devise localized renders, pages allowlist, flag-gated sell-to-us, setting
  casting + cache invalidation, country/user validations, `from_omniauth`.
- Remember `env -u BUNDLE_FORCE_RUBY_PLATFORM` for any bundler/rake command
  run outside `bin/dev`.

## Open items

- Phase 1: categories + listings models, search (pg_search), seller profiles.
- Real category taxonomy eventually from DB (currently a helper constant).
- Wishlist/notifications/cart are `#` placeholders in the header.
- CI not set up yet; `rubocop -A` touches `config/initializers/devise.rb`
  (already applied).
- No commit made for Phase 0 — awaiting user review.
