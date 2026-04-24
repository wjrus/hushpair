Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"
  get "about", to: "pages#about"
  get "privacy", to: "pages#privacy"
  get "terms", to: "pages#terms"

  resources :rooms, only: [ :create, :show ], param: :slug do
    post :join, on: :member
    patch :retention, on: :member, action: :update_retention
    post :leave, on: :member
    post :end_chat, on: :member
  end

  namespace :api do
    namespace :v1 do
      resource :anonymous_session, only: :create

      resources :rooms, only: [ :create, :show ], param: :public_id do
        post :join, to: "room_joins#create"
        resource :participant, only: :update, controller: "participants"
        resources :messages, only: [ :index, :create ]
        resource :presence, only: :create, controller: "presence"
        resource :typing, only: :create, controller: "typing"
        resource :leave, only: :create, controller: "leaves"
        resource :end_chat, only: :create, controller: "end_chats"
        resources :reports, only: :create
      end
    end
  end

end
