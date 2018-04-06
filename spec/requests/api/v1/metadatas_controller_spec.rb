require 'swagger_helper'
require_relative 'request_errors'

RSpec.describe Api::V1::MetadatasController, type: :request do

  before(:all) do
    @metadata = FactoryBot.create :metadata
    @resource = @metadata.resource
    @application = @metadata.application
    @other_application_metadata = FactoryBot.create :metadata
  end

  metadata_schema_reference = { '$ref': '#/definitions/metadata' }
  valid_type = described_class.valid_type
  it_behaves_like 'api v1 request errors',
                   application_proc: -> { @application },
                   base_path_template: '/resources/{resource_id}/metadatas',
                   schema_reference: metadata_schema_reference,
                   valid_type: valid_type,
                   id_scope: 'Resource',
                   path_params_proc: -> do
                     parameter name: :resource_id, in: :path, type: :string,
                               description: "The associated Resource's Id"

                     let(:resource_id) { @resource.uuid }
                   end

  no_data_setup = ->(on) do
    tags valid_type.classify
    security [ apiToken: [] ]
    schemes 'https'
    produces CONTENT_TYPE
    parameter name: :resource_id, in: :path, type: :string,
              description: "The associated Resource's Id"
    parameter name: :id, in: :path, type: :string,
              description: "The Metadata object's Id" if on == :member
  end
  data_setup = ->(on) do
    instance_exec on, &no_data_setup
    consumes CONTENT_TYPE
    parameter name: :metadata, in: :body, schema: metadata_schema_reference
  end

  create_member_setup = -> do
    instance_exec :member, &data_setup
    operationId 'createResourceMetadataWithId'
  end

  let(:resource_id) { @resource.uuid }
  let(:id)          { @metadata.uuid }

  after do |example|
    example.metadata[:response][:examples] = {
      'application/json' => JSON.parse(response.body, symbolize_names: true)
    }
  end

  context 'with valid Accept and API token headers' do
    let(:Accept)                                         { CONTENT_TYPE }
    let(Api::JsonApiController::API_TOKEN_HEADER.to_sym) { @application.token }

    path '/resources/{resource_id}/metadatas' do
      get 'List Metadatas created by the current application for the given Resource' do
        instance_exec :collection, &no_data_setup
        operationId 'getResourceMetadatas'

        response 200, 'success' do
          schema metadata_schema_reference

          run_test! do |response|
            expect(response.body_hash).to eq JSON.parse(
              Api::V1::MetadataSerializer.new([ @metadata ]).serialized_json
            ).deep_symbolize_keys
          end
        end
      end

      post 'Create a new Metadata with a random Id for the given Resource' do
        instance_exec :collection, &data_setup
        operationId 'createResourceMetadata'

        let(:uri)      { "https://example.com/assessments/#{SecureRandom.uuid}" }
        let(:metadata) do
          Api::V1::MetadataSerializer.new(@metadata).serializable_hash.tap do |hash|
            hash[:data].delete(:id)
          end
        end
        let(:expected_response) do
          JSON.parse(metadata.to_json).deep_symbolize_keys.tap do |hash|
            hash[:data][:id] = kind_of(String)
          end
        end

        response 201, 'Metadata created' do
          schema metadata_schema_reference

          run_test! { |response| expect(response.body_hash).to match expected_response }
        end
      end
    end

    path '/resources/{resource_id}/metadatas/{id}' do
      get 'View the Metadata with the given Id for the given Resource' do
        instance_exec :member, &no_data_setup
        operationId 'getResourceMetadataWithId'

        context 'when the Metadata was created by the current application' do
          response 200, 'success' do
            schema metadata_schema_reference

            run_test! do |response|
              expect(response.body_hash).to eq JSON.parse(
                Api::V1::MetadataSerializer.new(@metadata).serialized_json
              ).deep_symbolize_keys
            end
          end
        end
      end

      context 'when the Metadata does not exist or was created by a different application' do
        before(:all) do
          DatabaseCleaner.start

          @application_user = @metadata.application_user

          other_application = FactoryBot.create :application
          @metadata.update_attribute :application, other_application
          @metadata.update_attribute :application_user, nil
        end
        after(:all) do
          DatabaseCleaner.clean

          @metadata.reload
        end

        let(:metadata) do
          Api::V1::MetadataSerializer.new(@metadata).serializable_hash.tap do |hash|
            hash[:data][:relationships][:application][:data][:id] = @application.uuid
            hash[:data][:relationships][:application_user][:data] = {
              id: @application_user.uuid, type: :application_user
            }
          end
        end

        post 'Create a new Metadata with the given Id for the given Resource' do
          instance_exec &create_member_setup

          response 201, 'Metadata created' do
            schema metadata_schema_reference

            run_test! do |response|
              expect(response.body_hash).to eq JSON.parse(metadata.to_json).deep_symbolize_keys
            end
          end
        end
      end

      context 'when the Metadata already exists' do
        let(:metadata) { Api::V1::MetadataSerializer.new(@metadata).serializable_hash }

        post 'Create a new Metadata with the given Id for the given Resource' do
          instance_exec &create_member_setup

          response 409, 'Metadata uuid already exists' do
            schema metadata_schema_reference

            run_test! do |response|
              expect(response.errors.first[:status]).to eq '409'
              expect(response.errors.first[:code]).to eq 'uuid_has_already_been_taken'
              expect(response.errors.first[:title]).to eq 'Metadata Invalid'
              expect(response.errors.first[:detail]).to eq 'Uuid has already been taken.'
            end
          end
        end
      end

      [ :put, :patch ].each do |verb|
        public_send verb, 'Update the Metadata with the given Id for the given Resource' do
          instance_exec :member, &data_setup
          operationId 'updateResourceMetadataWithId'

          after(:all) { @metadata.reload }

          let(:metadata) do
            Api::V1::MetadataSerializer.new(@other_application_metadata)
                                       .serializable_hash
                                       .tap do |hash|
              hash[:data][:id] = @metadata.uuid
              hash[:data][:relationships][:application][:data][:id] = @application.uuid
              hash[:data][:relationships][:application_user][:data] = nil
              hash[:data][:relationships][:resource][:data][:id] = @resource.uuid
            end
          end

          context 'when the Metadata was created by the current application' do
            response 200, 'Metadata updated' do
              schema metadata_schema_reference

              run_test! do |response|
                expect(response.body_hash).to eq JSON.parse(metadata.to_json).deep_symbolize_keys
              end
            end
          end
        end
      end

      delete 'Delete the Metadata with the given Id for the given Resource' do
        instance_exec :member, &no_data_setup
        operationId 'deleteResourceMetadataWithId'

        after(:all) { @metadata.reload }

        context 'when the Metadata was created by the current application' do
          response 200, 'Metadata deleted' do
            schema metadata_schema_reference

            run_test! do |response|
              expect(response.body_hash).to eq JSON.parse(
                Api::V1::MetadataSerializer.new(@metadata).serialized_json
              ).deep_symbolize_keys
            end
          end
        end
      end
    end
  end
end
