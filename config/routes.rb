Rails.application.routes.draw do
  root "downloads#index"

  resources :downloads, only: %i[index create destroy] do
    collection do
      get :status
    end
    member do
      post :pause
      post :resume
      post :cancel
      delete :destroy_file
    end
  end

  # Health check (used by Uptime Kuma). Not behind the login.
  get "up" => "rails/health#show", as: :rails_health_check
end
