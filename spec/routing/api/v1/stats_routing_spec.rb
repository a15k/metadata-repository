require 'rails_helper'

RSpec.describe 'stats API V1 routes', type: :routing do
  let(:resource_uuid) { SecureRandom.uuid }
  let(:stats_uuid)    { SecureRandom.uuid }

  context 'GET /api/resources/:resource_uuid/stats' do
    it 'routes to api/v1/stats#index.json' do
      expect(get: "/api/resources/#{resource_uuid}/stats").to(
        route_to(
          controller: 'api/v1/stats',
          action: 'index',
          format: :json,
          resource_uuid: resource_uuid
        )
      )
    end
  end

  context 'POST /api/resources/:resource_uuid/stats' do
    it 'routes to api/v1/stats#create.json' do
      expect(post: "/api/resources/#{resource_uuid}/stats").to(
        route_to(
          controller: 'api/v1/stats',
          action: 'create',
          format: :json,
          resource_uuid: resource_uuid
        )
      )
    end
  end

  context 'POST /api/resources/:resource_uuid/stats/:stats_uuid' do
    it 'routes to api/v1/stats#create.json' do
      expect(post: "/api/resources/#{resource_uuid}/stats/#{stats_uuid}").to(
        route_to(
          controller: 'api/v1/stats',
          action: 'create',
          format: :json,
          resource_uuid: resource_uuid,
          uuid: stats_uuid
        )
      )
    end
  end

  context 'PUT /api/resources/:resource_uuid/stats/:stats_uuid' do
    it 'routes to api/v1/stats#update.json' do
      expect(put: "/api/resources/#{resource_uuid}/stats/#{stats_uuid}").to(
        route_to(
          controller: 'api/v1/stats',
          action: 'update',
          format: :json,
          resource_uuid: resource_uuid,
          uuid: stats_uuid
        )
      )
    end
  end

  context 'PATCH /api/resources/:resource_uuid/stats/:stats_uuid' do
    it 'routes to api/v1/stats#update.json' do
      expect(patch: "/api/resources/#{resource_uuid}/stats/#{stats_uuid}").to(
        route_to(
          controller: 'api/v1/stats',
          action: 'update',
          format: :json,
          resource_uuid: resource_uuid,
          uuid: stats_uuid
        )
      )
    end
  end

  context 'DELETE /api/resources/:resource_uuid/stats/:stats_uuid' do
    it 'routes to api/v1/stats#destroy.json' do
      expect(delete: "/api/resources/#{resource_uuid}/stats/#{stats_uuid}").to(
        route_to(
          controller: 'api/v1/stats',
          action: 'destroy',
          format: :json,
          resource_uuid: resource_uuid,
          uuid: stats_uuid
        )
      )
    end
  end
end
