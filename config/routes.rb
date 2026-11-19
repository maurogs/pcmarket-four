Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # OmniAuth callbacks cannot be nested under a dynamic segment, so they are
  # routed outside the locale scope (the locale cookie still applies).
  devise_for :users, only: :omniauth_callbacks,
                     controllers: { omniauth_callbacks: "users/omniauth_callbacks" }

  # Public site, localized through an optional URL prefix (/es/pages/about, /de/...).
  scope "(:locale)", locale: /en|es|fr|de|it|pt/ do
    devise_for :users, skip: :omniauth_callbacks

    root "home#index"

    resources :pages, only: :show
    resource :search, only: :show, controller: "searches"
    resource :sell_to_us, only: :show

    # Newsletter signup placeholder (persists nothing yet).
    resources :newsletter_subscribers, only: :create
  end
end
