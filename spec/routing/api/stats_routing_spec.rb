require 'rails_helper'

RSpec.describe 'stats API routes', type: :routing do
  let(:resource_uuid) { SecureRandom.uuid }
  let(:metadata_uuid) { SecureRandom.uuid }

  context 'POST /api/resources/:resource_uuid/stats' do
    it 'routes to api/v1/stats#create.json' do
      expect(post: "/api/resources/#{resource_uuid}/stats").to(
        route_to(
          controller: 'api/v1/stats',
          action: 'create',
          format: :json,
          resource_id: resource_uuid
        )
      )
    end
  end

  context 'POST /api/resources/:resource_uuid/stats/:metadata_uuid' do
    it 'routes to api/v1/stats#create.json' do
      expect(post: "/api/resources/#{resource_uuid}/stats/#{metadata_uuid}").to(
        route_to(
          controller: 'api/v1/stats',
          action: 'create',
          format: :json,
          resource_id: resource_uuid,
          id: metadata_uuid
        )
      )
    end
  end

  context 'PUT /api/resources/:resource_uuid/stats/:metadata_uuid' do
    it 'routes to api/v1/stats#update.json' do
      expect(put: "/api/resources/#{resource_uuid}/stats/#{metadata_uuid}").to(
        route_to(
          controller: 'api/v1/stats',
          action: 'update',
          format: :json,
          resource_id: resource_uuid,
          id: metadata_uuid
        )
      )
    end
  end

  context 'PATCH /api/resources/:resource_uuid/stats/:metadata_uuid' do
    it 'routes to api/v1/stats#update.json' do
      expect(patch: "/api/resources/#{resource_uuid}/stats/#{metadata_uuid}").to(
        route_to(
          controller: 'api/v1/stats',
          action: 'update',
          format: :json,
          resource_id: resource_uuid,
          id: metadata_uuid
        )
      )
    end
  end
end
