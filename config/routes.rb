Rails.application.routes.draw do
  namespace :api do
    api_version(
      module: 'V1',
      header: { name: 'Accept', value: 'application/vnd.metadata.a15k.org; version=1' },
      defaults: { format: :json },
      default: true
    ) do
      resources :resources, except: [ :index ] do
        resources :metadatas, except: [ :index ] do
          post :/, action: :create, on: :member
        end

        resources :stats, except: [ :index ] do
          post :/, action: :create, on: :member
        end

        match :search, via: [ :get, :post ], on: :collection

        post :/, action: :create, on: :member
      end
    end
  end
end
