Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # OmniAuth callbacks cannot be nested under a dynamic segment, so they are
  # routed outside the locale scope (the locale cookie still applies).
  devise_for :users, only: :omniauth_callbacks,
                     controllers: { omniauth_callbacks: "users/omniauth_callbacks" }

  # Public site, localized through an optional URL prefix (/es/pages/about, /de...).
  # Requests without a prefix negotiate the locale from cookie/header; request-time
  # path helpers add the current locale via ApplicationController#default_url_options.
  scope "(:locale)", locale: /en|es|fr|de|it|pt/ do
    devise_for :users, skip: :omniauth_callbacks

    root "home#index"

    resources :pages, only: :show

    # Catalog storefront (Phase 1b).
    resources :categories, only: :show, path: "c", param: :slug
    resources :listings, only: :show, path: "l"
    resources :stores, only: :show, path: "s", param: :slug do
      # Follow/unfollow: POST + DELETE /s/:store_slug/follow (singular — a
      # user has at most one follow per store, so the URL needs no id).
      resource :follow, only: %i[create destroy], controller: "stores/follows"
    end

    resource :search, only: :show, controller: "searches"
    resource :sell_to_us, only: :show

    # Cart (Phase 4 step 1). Singular — one cart per visitor/user, so the URL
    # never carries an id; cart items are addressed by their row id. Both
    # controllers 404 while checkout_enabled is off.
    resource :cart, only: :show
    resources :cart_items, only: %i[create update destroy]

    # Checkout (Phase 4 step 3). Singular — one cart per visitor, so the
    # checkout URL never carries an id. The confirmation page is addressed
    # by the checkout_group uuid the Placer stamps on the placed orders.
    resource :checkout, only: %i[show create]
    resources :checkout_confirmations, only: :show, param: :group

    # "Sell on PCMarket" landing page (Phase 3 step 6). Singular — one public
    # selling page per locale, so the URL never carries an id.
    resource :selling, only: :show, path: "sell"
    resource :pc_finder, only: :show, path: "pc-finder"

    # Newsletter signup placeholder (persists nothing yet).
    resources :newsletter_subscribers, only: :create

    # Signed-in account area (Phase 2).
    namespace :account do
      resource :profile, only: %i[edit update]
      resource :password, only: %i[edit update]
      resource :notifications, only: %i[edit update]

      resources :addresses, except: :show do
        # Singular nested resource: PATCH /account/addresses/:address_id/default
        # promotes that address to the user's default.
        resource :default, only: :update, controller: "address_defaults"
      end

      # GDPR (Phase 2 step 6). Singular — one export / one deletion per
      # signed-in user, so the URL never carries an id.
      resource :data_export, only: %i[show create]
      resource :deletion, only: %i[show destroy]
    end

    # Seller area (Phase 2): "open your store" + store settings. Singular —
    # a user owns at most one store, so the URL never carries an id and other
    # sellers' stores are simply unreachable. Listings are scoped to
    # current_user.store in the controller, so foreign ids 404.
    namespace :seller do
      resource :store, only: %i[new create edit update]
      # Seller dashboard (Phase 3 step 5). Singular — one store per user, so
      # the URL never carries an id.
      resource :dashboard, only: :show
      # Stripe Connect payouts (Phase 4 step 4a). Singular for the same
      # reason; create 303s off-site to Stripe's hosted onboarding.
      resource :payout_account, only: %i[show create]
      resources :listings, only: %i[index new create edit update destroy] do
        # Lifecycle actions as singular nested resources (Phase 3 step 4): a
        # listing has at most one submission / pause / sale per action, so the
        # URLs carry no extra ids. Pause is create (published → paused) +
        # destroy (paused → published via resume).
        resource :submission, only: :create, controller: "listings/submissions"
        resource :pause, only: %i[create destroy], controller: "listings/pauses"
        resource :sale, only: :create, controller: "listings/sales"
      end
      # Turbo Frame endpoint for the sell form's category-driven spec fields
      # (GET /seller/listing_spec_fields?category_id=…[&listing_id=…]).
      resource :listing_spec_fields, only: :show
    end
  end
end
