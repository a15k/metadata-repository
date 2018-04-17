require 'swagger_helper'
require_relative 'request_errors'

RSpec.describe Api::V1::ResourcesController, type: :request do

  before(:all) do
    @resource = FactoryBot.create :resource
    @application = @resource.application
    @other_application_resource = FactoryBot.create :resource
  end

  resource_schema_reference = { '$ref': '#/definitions/resource' }
  valid_type = described_class.valid_type
  it_behaves_like 'api v1 request errors',
                   application_proc: -> { @application },
                   base_path_template: '/resources',
                   schema_reference: resource_schema_reference,
                   valid_type: valid_type

  no_data_setup = ->(on) do
    tags valid_type.classify
    security [ apiToken: [] ]
    schemes 'https'
    produces CONTENT_TYPE
    parameter name: :id, in: :path, type: :string,
              description: "The Resource object's Id",
              schema: { type: :string, format: :uuid },
              example: SecureRandom.uuid if on == :member
  end
  data_setup = ->(on) do
    instance_exec on, &no_data_setup
    consumes CONTENT_TYPE
    parameter name: :resource, in: :body, schema: resource_schema_reference
  end

  index_setup = -> do
    instance_exec :collection, &no_data_setup
    operationId 'getResources'
    parameter name: :'filter[query]',    in: :query, type: :string, required: false,
              description: 'Query used for full text search on the Resources',
              schema: { type: :string },
              example: 'physics'
    parameter name: :'filter[language]', in: :query, type: :string, required: false,
              description: 'Language used for full text search on the Resources',
              schema: { type: :string },
              example: 'english'
  end
  create_collection_setup = -> do
    instance_exec :collection, &data_setup
    operationId 'createResource'
  end
  create_member_setup = -> do
    instance_exec :member, &data_setup
    operationId 'createResourceWithId'
  end

  let(:id) { @resource.uuid }

  after do |example|
    (example.metadata.dig(:operation, :parameters) || []).select do |parameter|
      parameter[:id] == :body
    end.each do |parameter|
      parameter['example'] = request.body.read
      request.body.rewind
    end
    example.metadata[:response][:examples] = {
      CONTENT_TYPE => JSON.parse(response.body, symbolize_names: true)
    }
  end

  context 'with valid Accept and API token headers' do
    let(:Accept)                                         { CONTENT_TYPE }
    let(Api::JsonApiController::API_TOKEN_HEADER.to_sym) { @application.token }

    path '/resources' do
      context 'with no filter param' do
        get 'List Resources created by all applications' do
          instance_exec &index_setup

          response 200, 'success' do
            schema resource_schema_reference

            let!(:expected_response) do
              JSON.parse(
                Api::V1::ResourceSerializer.new(Resource.all).serialized_json
              ).deep_symbolize_keys.tap do |expected|
                expected[:data] = a_collection_containing_exactly *expected[:data]
              end
            end

            run_test! { |response| expect(response.body_hash).to match expected_response }
          end
        end
      end

      context 'with a filter param' do
        before(:all) do
          DatabaseCleaner.start

          simple  = FactoryBot.create :language, name: 'simple'
          english = FactoryBot.create :language, name: 'english'

          all_queries = [ 'lorem', 'jumps', 'jump', 'jumping', 'jumped' ]
          [ @resource, @other_application_resource ] + 10.times.map do
            FactoryBot.create :resource, application: @application, language: simple
          end.each do |resource|
            resource.destroy if all_queries.any? do |query|
              resource.content.downcase.include?(query) || (
                !resource.title.nil? && resource.title.downcase.include?(query)
              )
            end
          end

          @title_resource = FactoryBot.create(
            :resource, application: @application,
                       title: 'Lorem Ipsum',
                       content: 'None',
                       language: simple
          )
          @content_resource = FactoryBot.create(
            :resource, application: @application,
                       title: nil,
                       content: 'Lorem Ipsum',
                       language: simple
          )
          @both_resource = FactoryBot.create(
            :resource, application: @application,
                       title: 'Lorem Ipsum',
                       content: 'Lorem Ipsum',
                       language: simple
          )
          @fox_and_dog_resource = FactoryBot.create(
            :resource, application: @application,
                       title: 'The fox and the dog',
                       content: 'The quick brown fox jumps over the lazy dog.',
                       language: english
          )
        end
        after(:all) do
          DatabaseCleaner.clean

          @resource.reload
        end

        context 'with no language param' do
          let(:'filter[query]') { 'lorem' }

          get 'List Resources created by all applications' do
            instance_exec &index_setup

            response 200, 'success' do
              schema resource_schema_reference

              let!(:expected_response) do
                JSON.parse(
                  Api::V1::ResourceSerializer.new(
                    Resource.search('lorem', 'simple').with_pg_search_highlight
                  ).serialized_json
                ).deep_symbolize_keys
              end
              before do
                expect(Resource).to receive(:search).with('lorem', 'simple').and_call_original
              end

              run_test! { |response| expect(response.body_hash).to eq expected_response }
            end
          end
        end

        context 'with a language param' do
          let(:'filter[query]')    { 'jumps' }
          let(:'filter[language]') { 'english' }

          get 'List Resources created by all applications' do
            instance_exec &index_setup

            response 200, 'success' do
              schema resource_schema_reference

              let!(:expected_response) do
                JSON.parse(
                  Api::V1::ResourceSerializer.new(
                    Resource.search('jumps', 'english').with_pg_search_highlight
                  ).serialized_json
                ).deep_symbolize_keys
              end
              before do
                expect(Resource).to receive(:search).with('jumps', 'english').and_call_original
              end

              run_test! { |response| expect(response.body_hash).to eq expected_response }
            end
          end
        end
      end

      context 'when the provided uri does not yet exist' do
        let(:uri)      { "https://example.com/assessments/#{SecureRandom.uuid}" }
        let(:resource) do
          Api::V1::ResourceSerializer.new(@resource).serializable_hash.tap do |hash|
            hash[:data].delete(:id)
            hash[:data][:attributes][:uri] = uri
          end
        end
        let(:expected_response) do
          JSON.parse(resource.to_json).deep_symbolize_keys.tap do |hash|
            hash[:data][:id] = kind_of(String)
          end
        end

        post 'Create a new Resource with a random Id' do
          instance_exec &create_collection_setup

          response 201, 'Resource created' do
            schema resource_schema_reference

            run_test! { |response| expect(response.body_hash).to match expected_response }
          end
        end
      end

      context 'when the provided uri already exists' do
        let(:resource) do
          Api::V1::ResourceSerializer.new(@resource).serializable_hash.tap do |hash|
            hash[:data].delete(:id)
          end
        end

        post 'Create a new Resource with a random Id' do
          instance_exec &create_collection_setup

          response 409, 'Resource uri already exists' do
            schema resource_schema_reference

            run_test! do |response|
              expect(response.errors.first[:status]).to eq '409'
              expect(response.errors.first[:code]).to eq 'uri_has_already_been_taken'
              expect(response.errors.first[:title]).to eq 'Resource Invalid'
              expect(response.errors.first[:detail]).to eq 'Uri has already been taken.'
            end
          end
        end
      end
    end

    path '/resources/{id}' do
      get 'View the Resource with the given Id' do
        instance_exec :member, &no_data_setup
        operationId 'getResourceWithId'

        context 'when the Resource was created by the current application' do
          response 200, 'success' do
            schema resource_schema_reference

            run_test! do |response|
              expect(response.body_hash).to eq JSON.parse(
                Api::V1::ResourceSerializer.new(@resource).serialized_json
              ).deep_symbolize_keys
            end
          end
        end
      end

      context 'when the Resource does not exist or was created by a different application' do
        before(:all) do
          DatabaseCleaner.start

          @application_user = @resource.application_user

          other_application = FactoryBot.create :application
          @resource.update_attribute :application, other_application
          @resource.update_attribute :application_user, nil
        end
        after(:all) do
          DatabaseCleaner.clean

          @resource.reload
        end

        let(:resource) do
          Api::V1::ResourceSerializer.new(@resource).serializable_hash.tap do |hash|
            hash[:data][:relationships][:application][:data][:id] = @application.uuid
            hash[:data][:relationships][:application_user][:data] = {
              id: @application_user.uuid, type: :application_user
            }
          end
        end

        context 'when the provided uri does not yet exist' do
          post 'Create a new Resource with the given Id' do
            instance_exec &create_member_setup

            response 201, 'Resource created' do
              schema resource_schema_reference

              run_test! do |response|
                expect(response.body_hash).to eq JSON.parse(resource.to_json).deep_symbolize_keys
              end
            end
          end
        end

        context 'when the provided uri already exists' do
          before { FactoryBot.create :resource, application: @application, uri: @resource.uri }

          post 'Create a new Resource with the given Id' do
            instance_exec &create_member_setup

            response 409, 'Resource uri already exists' do
              schema resource_schema_reference

              run_test! do |response|
                expect(response.errors.first[:status]).to eq '409'
                expect(response.errors.first[:code]).to eq 'uri_has_already_been_taken'
                expect(response.errors.first[:title]).to eq 'Resource Invalid'
                expect(response.errors.first[:detail]).to eq 'Uri has already been taken.'
              end
            end
          end
        end
      end

      context 'when the Resource already exists' do
        let(:resource) { Api::V1::ResourceSerializer.new(@resource).serializable_hash }

        post 'Create a new Resource with the given Id' do
          instance_exec &create_member_setup

          response 409, 'Resource uuid already exists' do
            schema resource_schema_reference

            run_test! do |response|
              expect(response.errors.first[:status]).to eq '409'
              expect(response.errors.first[:code]).to eq 'uuid_has_already_been_taken'
              expect(response.errors.first[:title]).to eq 'Resource Invalid'
              expect(response.errors.first[:detail]).to eq 'Uuid has already been taken.'
            end
          end
        end
      end

      [ :put, :patch ].each do |verb|
        public_send verb, 'Update the Resource with the given Id' do
          instance_exec :member, &data_setup
          operationId 'updateResourceWithId'

          after(:all) { @resource.reload }

          let(:resource) do
            Api::V1::ResourceSerializer.new(@other_application_resource)
                                       .serializable_hash
                                       .tap do |hash|
              hash[:data][:id] = @resource.uuid
              hash[:data][:relationships][:application][:data][:id] = @application.uuid
              hash[:data][:relationships][:application_user][:data] = nil
            end
          end

          context 'when the Resource was created by the current application' do
            response 200, 'Resource updated' do
              schema resource_schema_reference

              run_test! do |response|
                expect(response.body_hash).to eq JSON.parse(resource.to_json).deep_symbolize_keys
              end
            end
          end
        end
      end

      delete 'Delete the Resource with the given Id' do
        instance_exec :member, &no_data_setup
        operationId 'deleteResourceWithId'

        after(:all) { @resource.reload }

        context 'when the Resource was created by the current application' do
          response 200, 'Resource deleted' do
            schema resource_schema_reference

            run_test! do |response|
              expect(response.body_hash).to eq JSON.parse(
                Api::V1::ResourceSerializer.new(@resource).serialized_json
              ).deep_symbolize_keys
            end
          end
        end
      end
    end
  end
end
