Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Root route
  root "downloads#index"

  # Downloads routes
  resources :downloads do
    member do
      post :pause
      post :resume
      post :cancel
      delete :destroy_file
    end
  end

  # API routes for AJAX requests
  namespace :api do
    resources :downloads, only: [:index, :show, :create, :update, :destroy] do
      member do
        post :pause
        post :resume
        post :cancel
      end
    end
  end

  # SFTP Configuration
  resource :sftp_config, only: [:show, :update]

  # Sidekiq Web UI (optional, for monitoring)
  require 'sidekiq/web'
  mount Sidekiq::Web => '/sidekiq'

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
