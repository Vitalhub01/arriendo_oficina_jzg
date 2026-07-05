# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :users, controllers: {
    registrations: 'users/registrations',
    passwords: 'users/passwords'
  }

  root 'home#index'

  resource :profile, only: %i[show edit update], controller: 'users/profiles'
  resource :onboarding, only: %i[show update], controller: 'onboarding'

  resources :spaces, only: %i[index show] do
    member do
      get :availability
    end
    resources :bookings, only: %i[create]
  end

  resources :bookings, only: %i[index show] do
    member do
      get :checkout
      patch :cancel
      patch :reschedule
    end
    resource :testimonial, only: [:create], controller: 'testimonials'
  end

  resource :membership, only: %i[show create], controller: 'memberships'

  get 'terminos', to: 'pages#terms', as: :terms
  get 'privacidad', to: 'pages#privacy', as: :privacy
  get 'cancelacion', to: 'pages#cancellation', as: :cancellation_policy

  namespace :admin do
    root to: 'dashboard#index'
    resource :office, only: %i[edit update]
    resources :spaces
    resources :jornada_definitions
    resources :pricing_rules
    resources :professionals, only: %i[index show update]
    resources :bookings, only: %i[index show update]
    resources :testimonials, only: %i[index update]
    resources :membership_plans
    resources :memberships, only: [:index]
    resources :faqs
    resource :site_settings, only: %i[edit update]

    authenticate :user, ->(u) { u.admin? } do
      mount Sidekiq::Web => '/sidekiq'
    end
  end

  namespace :payments do
    post 'webhooks/mercadopago', to: 'webhooks#mercadopago'
  end
end
