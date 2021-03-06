Rails.application.routes.draw do
  mount Rswag::Ui::Engine  => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'

  namespace :api do
    api_version(
      module: 'V1',
      path: { value: 'v1' },
      defaults: { format: :json },
      default: true
    ) do
      resources :application_users, param: :uuid do
        post :/, action: :create, on: :member
      end

      resources :resources, param: :uuid do
        resources :metadatas, param: :uuid do
          post :/, action: :create, on: :member
        end

        resources :stats, param: :uuid do
          post :/, action: :create, on: :member
        end

        post :/, action: :create, on: :member
      end

      get :metadatas, controller: :metadatas, action: :search

      get :stats,     controller: :stats,     action: :search
    end
  end
end
