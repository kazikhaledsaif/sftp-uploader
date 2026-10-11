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

  # Watchlist / tracker
  get "discover" => "titles#discover", as: :discover
  get "diary" => "viewings#index", as: :diary
  get "calendar" => "plans#index", as: :calendar
  resources :titles, path: "watchlist", only: %i[index show create update destroy] do
    collection do
      get :pick
    end
    member do
      post :refresh
    end
    resources :seasons, only: :update, controller: "title_seasons"
    resources :viewings, only: :create
    resources :plans, only: :create
  end
  resources :viewings, path: "diary", only: %i[update destroy]
  resources :plans, only: :destroy

  # Health check (used by Uptime Kuma). Not behind the login.
  get "up" => "rails/health#show", as: :rails_health_check
end
