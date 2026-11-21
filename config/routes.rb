Rails.application.routes.draw do
  # Health check is not localised.
  get "up" => "rails/health#show", as: :rails_health_check

  # Crawler endpoints live outside the locale scope and use absolute URLs.
  get "robots.txt" => "seo#robots", as: :robots, defaults: { format: :text }
  get "sitemap.xml" => "seo#sitemap", as: :sitemap, defaults: { format: :xml }

  # Devise does not allow OmniAuth callbacks inside a dynamic scope, so they
  # live outside the locale scope.
  devise_for :users, only: :omniauth_callbacks,
                     controllers: { omniauth_callbacks: "users/omniauth_callbacks" }

  scope "(:locale)", locale: /es|en|fr|de|it|pt/ do
    devise_for :users, skip: :omniauth_callbacks

    root "home#index"

    resources :listings, path: "l", only: %i[index show new create edit update destroy]
    get "c/*path" => "categories#show", as: :category, format: false
    get "search" => "listings#index", as: :search
    get "search/suggestions" => "search_suggestions#index", as: :search_suggestions

    resources :stores, only: :show, path: "s"
    resource :cart, only: :show, controller: "cart"
    resources :favorites, only: %i[index create destroy]
    resources :conversations, only: %i[index show]
    resources :orders, only: %i[index show]
    resource :account, only: :show, controller: "account"

    namespace :seller do
      root "dashboard#show"
    end

    get "pc-finder" => "pc_finder#show", as: :pc_finder
    get "sell" => "pages#sell", as: :sell
    get "sell-to-us" => "sell_offers#new", as: :sell_to_us

    resources :newsletter_subscribers, only: :create
    get "newsletter/confirm/:token" => "newsletter_subscribers#confirm",
        as: :confirm_newsletter

    get "legal/:slug" => "legal_pages#show", as: :legal_page
    get "trust" => "pages#trust", as: :trust
    get "help" => "pages#help", as: :help
    get "about" => "pages#about", as: :about

    namespace :admin do
      root "dashboard#show"
    end
  end
end
