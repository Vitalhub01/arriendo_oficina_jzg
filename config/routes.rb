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
      patch :apply_discount_code
    end
    resource :testimonial, only: [:create], controller: 'testimonials'
  end

  resource :membership, only: %i[show create], controller: 'memberships'

  get 'terminos', to: 'pages#terms', as: :terms
  get 'privacidad', to: 'pages#privacy', as: :privacy
  get 'cancelacion', to: 'pages#cancellation', as: :cancellation_policy

  get 'sitemap.xml', to: 'sitemaps#show', defaults: { format: :xml }

  namespace :admin do
    root to: 'dashboard#index'
    resource :office, only: %i[edit update], controller: 'office'
    resources :spaces do
      resource :availability, only: [:show], controller: 'spaces/availabilities'
      resources :schedule_blocks, controller: 'spaces/schedule_blocks', except: [:show] do
        member do
          post :override, action: :upsert_override
          delete :override, action: :destroy_override
          post :end_series, action: :end_series_from_date
        end
      end
      resources :volume_pricing_rules, controller: 'spaces/volume_pricing_rules', only: %i[create update destroy]
      resources :slot_rates, controller: 'spaces/slot_rates', except: [:show]
      resources :availability_rules, controller: 'spaces/availability_rules', except: %i[show edit update]
      resources :availability_blocks, controller: 'spaces/availability_blocks', except: %i[show edit update]
    end
    resources :jornada_definitions
    resources :pricing_rules
    resources :discount_codes
    resources :users, only: %i[index edit update]
    resources :professionals, only: %i[index show update]
    resources :bookings, only: %i[index show new create update] do
      collection do
        get :calendar
        get :day_contacts
      end
    end
    resources :testimonials, only: %i[index update]
    resources :membership_plans
    resources :memberships, only: [:index]
    resources :faqs
    resources :social_contacts, except: [:show]
    resource :site_settings, only: %i[edit update]

    authenticate :user, ->(u) { u.admin? } do
      mount Sidekiq::Web => '/sidekiq'
    end
  end

  namespace :payments do
    post 'webhooks/mercadopago', to: 'webhooks#mercadopago'
  end
end
