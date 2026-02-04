Rails.application.routes.draw do
  mount ActionCable.server => "/cable"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"

  post "/agents" => "agents#create"
  resources :matches, only: [:create] do
    post :join, on: :member
  end

  get "/admin/login" => "admin_sessions#new"
  post "/admin/login" => "admin_sessions#create"
  delete "/admin/logout" => "admin_sessions#destroy"

  get "/admin" => "admin/home#index", as: :admin_root
  namespace :admin do
    resources :agents, only: [:index, :show, :destroy]
    resources :matches, only: [:index, :show] do
      post :cancel, on: :member
      post :invalidate, on: :member
    end
    resources :tournament_interests, only: [:index]
    resources :audit_logs, only: [:index]
  end

  root "home#index"

  get "/leaderboard" => "leaderboards#index"
  get "/analytics" => "analytics#index"
  get "/analytics/h2h" => "analytics#h2h", as: :analytics_h2h
  get "/matches" => "matches_public#index", as: :public_matches
  get "/matches/:id" => "matches_public#show", as: :public_match
  get "/agents/:id" => "agents_public#show", as: :public_agent
  resources :tournaments, only: [:index, :show] do
    post :register, on: :member
    delete :withdraw, on: :member
  end
  post "/tournaments/interest" => "tournament_interests#create"

  get "/docs/:id" => "docs#show", as: :docs
end
