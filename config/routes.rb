Rails.application.routes.draw do
  # Health check is not localised.
  get "up" => "rails/health#show", as: :rails_health_check

  # Devise does not allow OmniAuth callbacks inside a dynamic scope, so they
  # live outside the locale scope.
  devise_for :users, only: :omniauth_callbacks,
                     controllers: { omniauth_callbacks: "users/omniauth_callbacks" }

  scope "(:locale)", locale: /es|en|fr|de|it|pt/ do
    devise_for :users, skip: :omniauth_callbacks

    root "home#index"
  end
end
