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
    resources :stores, only: :show, path: "s", param: :slug

    resource :search, only: :show, controller: "searches"
    resource :sell_to_us, only: :show
    resource :pc_finder, only: :show, path: "pc-finder"

    # Newsletter signup placeholder (persists nothing yet).
    resources :newsletter_subscribers, only: :create

    # Signed-in account area (Phase 2).
    namespace :account do
      resources :addresses, except: :show do
        # Singular nested resource: PATCH /account/addresses/:address_id/default
        # promotes that address to the user's default.
        resource :default, only: :update, controller: "address_defaults"
      end
    end
  end
end
