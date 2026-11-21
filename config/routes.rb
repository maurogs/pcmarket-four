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

  # Payment webhooks are called by providers, never inside a locale scope.
  post "webhooks/stripe" => "payments/stripe_webhooks#create", as: :stripe_webhook

  scope "(:locale)", locale: /es|en|fr|de|it|pt/ do
    devise_for :users, skip: :omniauth_callbacks,
                       controllers: { registrations: "users/registrations" }

    root "home#index"

    resources :listings, path: "l", only: %i[index show new create edit update destroy] do
      resource :submission, only: :create, module: :listings
      resource :pause, only: %i[create destroy], module: :listings
      resource :sale, only: :create, module: :listings
    end
    get "c/*path" => "categories#show", as: :category, format: false
    get "search" => "listings#index", as: :search
    get "search/suggestions" => "search_suggestions#index", as: :search_suggestions

    resources :stores, only: :show, path: "s"
    resource :cart, only: :show, controller: "cart"
    resources :cart_items, only: %i[create update destroy] do
      resource :favorite, only: :create, module: :cart_items
    end
    resource :checkout, only: %i[show create], controller: "checkouts" do
      resource :confirmation, only: :show, module: :checkout
    end
    resources :favorites, only: %i[index create destroy]
    resources :follows, only: %i[create destroy]
    resources :reports, only: %i[create]
    resources :saved_searches, only: %i[index create update destroy]
    resources :conversations, only: %i[index show create] do
      resources :messages, only: :create, module: :conversations
      resources :offers, only: :create, module: :conversations
      resource :read, only: :create, module: :conversations
      resource :archive, only: %i[create destroy], module: :conversations
    end
    resources :messages, only: [] do
      resource :offer_response, only: :create, module: :messages
    end
    resources :blocks, only: %i[index create destroy]
    resource :inbox_read_all, only: :create, controller: "conversations/read_alls"
    resources :followings, only: :index, path: "account/following", controller: "account/following"
    resources :orders, only: %i[index show], param: :number do
      resource :cancellation, only: :create, module: :orders
      resource :delivery_confirmation, only: :create, module: :orders
      resource :dispute, only: %i[new create], module: :orders
      resource :review, only: %i[new create], module: :orders
    end
    resources :notifications, only: %i[index update]
    post "notifications/read_all" => "notifications/read_alls#create", as: :notifications_read_all
    resource :account, only: %i[show update], controller: "account" do
      resource :password, only: %i[edit update], module: :account
      resources :addresses, only: %i[index new create edit update destroy], module: :account
      resource :notification_preferences, only: %i[edit update], module: :account
      resource :data_export, only: :create, module: :account
      resource :deletion, only: %i[new create], module: :account
    end

    namespace :seller do
      root "dashboard#show"
      resources :orders, only: %i[index show] do
        resource :shipment, only: :create, module: :orders
        resource :pickup, only: :create, module: :orders
        resource :payment, only: :create, module: :orders
        resource :cancellation, only: :create, module: :orders
        resource :packing_slip, only: :show, module: :orders
      end
      resources :order_exports, only: :create
      resources :review_replies, only: %i[create update]
      resource :store, only: %i[edit update], controller: "stores"
      resource :store_policy, only: %i[edit update], controller: "store_policies"
      resource :vacation, only: %i[edit update], controller: "vacations"
      resource :payout, only: :show, controller: "payouts"
      resources :listings, only: :index do
        resource :duplication, only: :create, module: :listings
      end
      resources :bulk_listing_actions, only: :create
      resources :feature_requests, only: %i[new create]
    end

    resource :pc_finder, only: :show, controller: "pc_finder", path: "pc-finder" do
      resources :results, only: :index, module: :pc_finder
    end
    get "sell" => "pages#sell", as: :sell
    resource :sell_offer_quote, only: :show, controller: "sell_offers/quotes", path: "sell-to-us/quote"
    resources :sell_offers, path: "sell-to-us", only: %i[index new create show] do
      resource :acceptance, only: :create, module: :sell_offers
      resource :decline, only: :create, module: :sell_offers
    end
    get "sell-to-us" => "sell_offers#index", as: :sell_to_us

    resources :newsletter_subscribers, only: :create
    get "newsletter/confirm/:token" => "newsletter_subscribers#confirm",
        as: :confirm_newsletter

    get "legal/:slug" => "legal_pages#show", as: :legal_page
    get "trust" => "pages#trust", as: :trust
    resources :help_articles, only: %i[index show], path: "help", param: :slug do
      resource :feedback, only: :create, controller: "help_article_feedbacks"
    end
    get "about" => "pages#about", as: :about

    namespace :admin do
      root "dashboard#show"
      get "moderation" => "moderation_queue#index", as: :moderation_queue
      get "search" => "search#index", as: :search

      resources :listings, only: %i[index show edit update destroy] do
        resource :approval, only: :create, controller: "listing_approvals"
        resource :rejection, only: :create, controller: "listing_rejections"
      end
      resources :bulk_listing_actions, only: :create

      resources :users, only: %i[index show edit update] do
        resource :suspension, only: %i[create destroy], controller: "user_suspensions"
        resource :ban, only: %i[create destroy], controller: "user_bans"
        resource :role, only: :update, controller: "user_roles"
        resource :confirmation, only: :create, controller: "user_confirmations"
        resource :password_reset, only: :create, controller: "user_password_resets"
        resource :impersonation, only: :create, controller: "impersonations"
        resource :deletion, only: :create, controller: "user_deletions"
      end
      resource :impersonation, only: :destroy, controller: "impersonations"
      resources :user_exports, only: :create

      resources :stores, only: %i[index show edit update] do
        resource :verification, only: %i[create destroy], controller: "store_verifications"
        resource :vacation, only: %i[create destroy], controller: "store_vacations"
      end

      resources :orders, only: %i[index show], param: :number do
        resource :payment, only: :create, controller: "order_payments"
        resource :cancellation, only: :create, controller: "order_cancellations"
        resource :refund, only: :create, controller: "order_refunds"
        resource :email, only: :create, controller: "order_emails"
        resources :notes, only: :create, controller: "order_notes"
      end
      resources :order_exports, only: :create
      resources :payments, only: :index
      resources :bulk_payments, only: :create

      resources :disputes, only: %i[index show] do
        resource :resolution, only: :create, controller: "dispute_resolutions"
      end

      resources :reports, only: %i[index show update]
      resources :bulk_report_actions, only: :create

      resources :reviews, only: %i[index show update destroy]

      resources :categories
      resource :category_positions, only: :update

      resources :filter_definitions do
        resources :filter_options, only: %i[create update destroy]
        resource :merge, only: :create, controller: "filter_option_merges"
        resource :bulk, only: :create, controller: "filter_option_bulks"
      end
      resource :filter_option_positions, only: :update

      resources :settings, only: :index
      patch "settings" => "settings#update", as: :save_settings

      resources :countries, only: %i[index update] do
        resources :regions, only: %i[index create update destroy]
      end

      resources :legal_pages
      resources :games
      resource :game_positions, only: :update
      resources :help_articles
      resource :help_article_positions, only: :update

      resources :newsletter_subscribers, only: %i[index destroy]
      resource :newsletter_export, only: :show, controller: "newsletter_exports"

      resources :feature_requests, only: %i[index show] do
        resource :approval, only: :create, controller: "feature_request_approvals"
      end

      resources :sell_offers, only: %i[index show update]
      resources :buyback_prices, except: :show

      resources :audit_logs, only: %i[index show]
      resources :placeholders, only: :show, param: :section
    end
  end
end
