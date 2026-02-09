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

  post "/operator_accounts" => "operator_accounts#create"
  get "/operator_accounts/me" => "operator_accounts#show"
  post "/operator_sessions" => "operator_sessions#create"
  delete "/operator_sessions" => "operator_sessions#destroy"
  get "/me/entitlements" => "operator_entitlements#show"
  post "/billing/checkout_sessions" => "billing_checkout_sessions#create"
  post "/billing/webhooks" => "billing_webhooks#create"
  post "/billing/stripe_webhooks" => "stripe_webhooks#create"

  get "/operator/login" => "operator_portal_sessions#new", as: :operator_login
  post "/operator/login" => "operator_portal_sessions#create"
  delete "/operator/logout" => "operator_portal_sessions#destroy", as: :operator_logout
  namespace :operator do
    get "/" => "dashboard#show", as: :root
    resources :agents, only: [] do
      patch :activate, on: :member
      patch :deactivate, on: :member
    end
    post "/reallocate_seats" => "dashboard#reallocate_seats", as: :reallocate_seats
  end

  post "/agents" => "agents#create"
  get "/time_control_presets" => "time_control_presets#index"
  resources :match_requests, only: [ :index, :create, :destroy ]
  resources :matches, only: [ :create ] do
    post :join, on: :member
  end

  get "/admin/login" => "admin_sessions#new"
  post "/admin/login" => "admin_sessions#create"
  delete "/admin/logout" => "admin_sessions#destroy"

  get "/admin" => "admin/home#index", as: :admin_root
  namespace :admin do
    get "/stripe" => "stripe_dashboard#show", as: :stripe_dashboard
    get "/billing/health" => "billing_health#show", as: :billing_health
    resources :agents, only: [ :index, :show, :destroy ]
    resources :operator_accounts, only: [ :index, :show ] do
      post :reallocate_seats, on: :member
    end
    resources :tournaments, only: [ :index, :show, :new, :create, :edit, :update ] do
      post :start, on: :member
      post :cancel, on: :member
      post :invalidate, on: :member
      post :repair_health, on: :member
      patch :time_controls, on: :member
    end
    resources :matches, only: [ :index, :show ] do
      post :cancel, on: :member
      post :invalidate, on: :member
    end
    resources :tournament_interests, only: [ :index ]
    resources :audit_logs, only: [ :index ]
  end

  root "home#index"

  get "/leaderboard" => "leaderboards#index"
  get "/analytics" => "analytics#index"
  get "/analytics/h2h" => "analytics#h2h", as: :analytics_h2h
  get "/matches" => "matches_public#index", as: :public_matches
  get "/matches/:id" => "matches_public#show", as: :public_match
  get "/agents/:id" => "agents_public#show", as: :public_agent
  resources :tournaments, only: [ :index, :show ] do
    post :register, on: :member
    delete :withdraw, on: :member
    get :bracket, on: :member
    get :table, on: :member
  end
  post "/tournaments/interest" => "tournament_interests#create"

  get "/docs/:id" => "docs#show", as: :docs
end
