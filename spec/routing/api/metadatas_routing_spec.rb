require 'rails_helper'

RSpec.describe 'metadatas API routes', type: :routing do
  let(:resource_uuid) { SecureRandom.uuid }
  let(:metadata_uuid) { SecureRandom.uuid }

  context 'POST /api/resources/:resource_uuid/metadatas' do
    it 'routes to api/v1/metadatas#create.json' do
      expect(post: "/api/resources/#{resource_uuid}/metadatas").to(
        route_to(
          controller: 'api/v1/metadatas',
          action: 'create',
          format: :json,
          resource_id: resource_uuid
        )
      )
    end
  end

  context 'POST /api/resources/:resource_uuid/metadatas/:metadata_uuid' do
    it 'routes to api/v1/metadatas#create.json' do
      expect(post: "/api/resources/#{resource_uuid}/metadatas/#{metadata_uuid}").to(
        route_to(
          controller: 'api/v1/metadatas',
          action: 'create',
          format: :json,
          resource_id: resource_uuid,
          id: metadata_uuid
        )
      )
    end
  end

  context 'PUT /api/resources/:resource_uuid/metadatas/:metadata_uuid' do
    it 'routes to api/v1/metadatas#update.json' do
      expect(put: "/api/resources/#{resource_uuid}/metadatas/#{metadata_uuid}").to(
        route_to(
          controller: 'api/v1/metadatas',
          action: 'update',
          format: :json,
          resource_id: resource_uuid,
          id: metadata_uuid
        )
      )
    end
  end

  context 'PATCH /api/resources/:resource_uuid/metadatas/:metadata_uuid' do
    it 'routes to api/v1/metadatas#update.json' do
      expect(patch: "/api/resources/#{resource_uuid}/metadatas/#{metadata_uuid}").to(
        route_to(
          controller: 'api/v1/metadatas',
          action: 'update',
          format: :json,
          resource_id: resource_uuid,
          id: metadata_uuid
        )
      )
    end
  end
end
