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

  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  scope "(:locale)", locale: /es|en|fr|de|it|pt/ do
    devise_for :users, skip: :omniauth_callbacks,
                       controllers: { registrations: "users/registrations" }

    root "home#index"

    resources :listings, path: "l", only: %i[index show new create edit update destroy]
    get "c/*path" => "categories#show", as: :category, format: false
    get "search" => "listings#index", as: :search
    get "search/suggestions" => "search_suggestions#index", as: :search_suggestions

    resources :stores, only: :show, path: "s"
    resource :cart, only: :show, controller: "cart"
    resources :cart_items, only: %i[create update destroy]
    resources :favorites, only: %i[index create destroy]
    resources :follows, only: %i[create destroy]
    resources :reports, only: %i[create]
    resources :saved_searches, only: %i[index create update destroy]
    resources :conversations, only: %i[index show create]
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
