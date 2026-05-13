Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :users, only: [:create] do
        resource :balance, only: [:show]
        resources :balance_transactions, only: [:create]
      end
      resources :transfers, only: [:create]
    end
  end
end
