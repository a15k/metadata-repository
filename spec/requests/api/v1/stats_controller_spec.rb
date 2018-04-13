require 'swagger_helper'
require_relative 'request_errors'

RSpec.describe Api::V1::StatsController, type: :request do

  before(:all) do
    @stats = FactoryBot.create :stats
    @resource = @stats.resource
    @application = @stats.application
    @other_application_stats = FactoryBot.create :stats
  end

  stats_schema_reference = { '$ref': '#/definitions/stats' }
  valid_type = described_class.valid_type
  it_behaves_like 'api v1 request errors',
                   application_proc: -> { @application },
                   base_path_template: '/resources/{resource_id}/stats',
                   schema_reference: stats_schema_reference,
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
              description: "The Stats object's Id" if on == :member
  end
  data_setup = ->(on) do
    instance_exec on, &no_data_setup
    consumes CONTENT_TYPE
    parameter name: :stats, in: :body, schema: stats_schema_reference
  end

  create_member_setup = -> do
    instance_exec :member, &data_setup
    operationId 'createResourceStatsWithId'
  end

  let(:resource_id) { @resource.uuid }
  let(:id)          { @stats.uuid }

  after do |example|
    example.metadata[:response][:examples] = {
      'application/json' => JSON.parse(response.body, symbolize_names: true)
    }
  end

  context 'with valid Accept and API token headers' do
    let(:Accept)                                         { CONTENT_TYPE }
    let(Api::JsonApiController::API_TOKEN_HEADER.to_sym) { @application.token }

    path '/resources/{resource_id}/stats' do
      get 'List Stats created by all applications for the given Resource' do
        instance_exec :collection, &no_data_setup
        operationId 'getResourceStats'

        response 200, 'success' do
          schema stats_schema_reference

          run_test! do |response|
            expect(response.body_hash).to eq JSON.parse(
              Api::V1::StatsSerializer.new([ @stats ]).serialized_json
            ).deep_symbolize_keys
          end
        end
      end

      post 'Create a new Stats with a random Id for the given Resource' do
        instance_exec :collection, &data_setup
        operationId 'createResourceStats'

        let(:uri)   { "https://example.com/assessments/#{SecureRandom.uuid}" }
        let(:stats) do
          Api::V1::StatsSerializer.new(@stats).serializable_hash.tap do |hash|
            hash[:data].delete(:id)
          end
        end
        let(:expected_response) do
          JSON.parse(stats.to_json).deep_symbolize_keys.tap do |hash|
            hash[:data][:id] = kind_of(String)
          end
        end

        response 201, 'Stats created' do
          schema stats_schema_reference

          run_test! { |response| expect(response.body_hash).to match expected_response }
        end
      end
    end

    path '/resources/{resource_id}/stats/{id}' do
      get 'View the Stats with the given Id for the given Resource' do
        instance_exec :member, &no_data_setup
        operationId 'getResourceStatsWithId'

        context 'when the Stats was created by the current application' do
          response 200, 'success' do
            schema stats_schema_reference

            run_test! do |response|
              expect(response.body_hash).to eq JSON.parse(
                Api::V1::StatsSerializer.new(@stats).serialized_json
              ).deep_symbolize_keys
            end
          end
        end
      end

      context 'when the Stats does not exist or was created by a different application' do
        before(:all) do
          DatabaseCleaner.start

          @application_user = @stats.application_user

          other_application = FactoryBot.create :application
          @stats.update_attribute :application, other_application
          @stats.update_attribute :application_user, nil
        end
        after(:all) do
          DatabaseCleaner.clean

          @stats.reload
        end

        let(:stats) do
          Api::V1::StatsSerializer.new(@stats).serializable_hash.tap do |hash|
            hash[:data][:relationships][:application][:data][:id] = @application.uuid
            hash[:data][:relationships][:application_user][:data] = {
              id: @application_user.uuid, type: :application_user
            }
          end
        end

        post 'Create a new Stats with the given Id for the given Resource' do
          instance_exec &create_member_setup

          response 201, 'Stats created' do
            schema stats_schema_reference

            run_test! do |response|
              expect(response.body_hash).to eq JSON.parse(stats.to_json).deep_symbolize_keys
            end
          end
        end
      end

      context 'when the Stats already exists' do
        let(:stats) { Api::V1::StatsSerializer.new(@stats).serializable_hash }

        post 'Create a new Stats with the given Id for the given Resource' do
          instance_exec &create_member_setup

          response 409, 'Stats uuid already exists' do
            schema stats_schema_reference

            run_test! do |response|
              expect(response.errors.first[:status]).to eq '409'
              expect(response.errors.first[:code]).to eq 'uuid_has_already_been_taken'
              expect(response.errors.first[:title]).to eq 'Stats Invalid'
              expect(response.errors.first[:detail]).to eq 'Uuid has already been taken.'
            end
          end
        end
      end

      [ :put, :patch ].each do |verb|
        public_send verb, 'Update the Stats with the given Id for the given Resource' do
          instance_exec :member, &data_setup
          operationId 'updateResourceStatsWithId'

          after(:all) { @stats.reload }

          let(:stats) do
            Api::V1::StatsSerializer.new(@other_application_stats)
                                       .serializable_hash
                                       .tap do |hash|
              hash[:data][:id] = @stats.uuid
              hash[:data][:relationships][:application][:data][:id] = @application.uuid
              hash[:data][:relationships][:application_user][:data] = nil
              hash[:data][:relationships][:resource][:data][:id] = @resource.uuid
            end
          end

          context 'when the Stats was created by the current application' do
            response 200, 'Stats updated' do
              schema stats_schema_reference

              run_test! do |response|
                expect(response.body_hash).to eq JSON.parse(stats.to_json).deep_symbolize_keys
              end
            end
          end
        end
      end

      delete 'Delete the Stats with the given Id for the given Resource' do
        instance_exec :member, &no_data_setup
        operationId 'deleteResourceStatsWithId'

        after(:all) { @stats.reload }

        context 'when the Stats was created by the current application' do
          response 200, 'Stats deleted' do
            schema stats_schema_reference

            run_test! do |response|
              expect(response.body_hash).to eq JSON.parse(
                Api::V1::StatsSerializer.new(@stats).serialized_json
              ).deep_symbolize_keys
            end
          end
        end
      end
    end
  end
end
