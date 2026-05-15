Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      post "users/auth", to: "auth#create"
      resources :users, only: [ :create ]

      resource :balance, only: [ :show ] do
        resources :adjustments, only: [ :create ], module: :balance
      end

      resources :transfers, only: [ :create ]
    end
  end
end
