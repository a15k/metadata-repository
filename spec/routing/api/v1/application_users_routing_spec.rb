require 'rails_helper'

RSpec.describe 'application_users API V1 routes', type: :routing do
  let(:application_user_uuid) { SecureRandom.uuid }

  context 'GET /api/application_users' do
    it 'routes to api/v1/application_users#index.json' do
      expect(get: "/api/application_users").to(
        route_to(controller: 'api/v1/application_users', action: 'index', format: :json)
      )
    end
  end

  context 'GET /api/application_users/:uuid' do
    it 'routes to api/v1/application_users#show.json with the given uuid' do
      expect(get: "/api/application_users/#{application_user_uuid}").to route_to(
        controller: 'api/v1/application_users',
        action: 'show',
        format: :json,
        uuid: application_user_uuid
      )
    end
  end

  context 'POST /api/application_users' do
    it 'routes to api/v1/application_users#create.json' do
      expect(post: "/api/application_users").to(
        route_to(controller: 'api/v1/application_users', action: 'create', format: :json)
      )
    end
  end

  context 'POST /api/application_users/:uuid' do
    it 'routes to api/v1/application_users#create.json' do
      expect(post: "/api/application_users/#{application_user_uuid}").to(
        route_to(
          controller: 'api/v1/application_users',
          action: 'create',
          format: :json,
          uuid: application_user_uuid
        )
      )
    end
  end

  context 'DELETE /api/application_users/:uuid' do
    it 'routes to api/v1/application_users#destroy.json' do
      expect(delete: "/api/application_users/#{application_user_uuid}").to(
        route_to(
          controller: 'api/v1/application_users',
          action: 'destroy',
          format: :json,
          uuid: application_user_uuid
        )
      )
    end
  end
end
