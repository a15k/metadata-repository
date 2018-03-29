require 'rails_helper'

RSpec.describe 'resources API V1 routes', type: :routing do
  let(:resource_uuid) { SecureRandom.uuid }

  context 'GET /api/resources' do
    it 'routes to api/v1/resources#index.json' do
      expect(get: "/api/resources").to(
        route_to(controller: 'api/v1/resources', action: 'index', format: :json)
      )
    end
  end

  context 'GET /api/resources/:uuid' do
    it 'routes to api/v1/resources#show.json with the given uuid' do
      expect(get: "/api/resources/#{resource_uuid}").to(
        route_to(controller: 'api/v1/resources', action: 'show', format: :json, uuid: resource_uuid)
      )
    end
  end

  context 'POST /api/resources' do
    it 'routes to api/v1/resources#create.json' do
      expect(post: "/api/resources").to(
        route_to(controller: 'api/v1/resources', action: 'create', format: :json)
      )
    end
  end

  context 'POST /api/resources/:uuid' do
    it 'routes to api/v1/resources#create.json' do
      expect(post: "/api/resources/#{resource_uuid}").to(
        route_to(
          controller: 'api/v1/resources',
          action: 'create',
          format: :json,
          uuid: resource_uuid
        )
      )
    end
  end

  context 'PUT /api/resources/:uuid' do
    it 'routes to api/v1/resources#update.json' do
      expect(put: "/api/resources/#{resource_uuid}").to(
        route_to(
          controller: 'api/v1/resources',
          action: 'update',
          format: :json,
          uuid: resource_uuid
        )
      )
    end
  end

  context 'PATCH /api/resources/:uuid' do
    it 'routes to api/v1/resources#update.json' do
      expect(patch: "/api/resources/#{resource_uuid}").to(
        route_to(
          controller: 'api/v1/resources',
          action: 'update',
          format: :json,
          uuid: resource_uuid
        )
      )
    end
  end
end
