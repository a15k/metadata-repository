require 'swagger_helper'
require_relative 'request_errors'

RSpec.describe Api::V1::ResourcesController, type: :request do

  before(:all) do
    @resource = FactoryBot.create :resource
    @application = @resource.application
    @other_application_resource = FactoryBot.create :resource
  end

  json_schema_hash = Api::V1::ResourceSerializer.json_schema_hash
  valid_type = described_class.valid_type
  it_behaves_like 'api v1 request errors',
                   application_proc: -> { @application },
                   base_path_template: '/api/resources',
                   json_schema_hash: json_schema_hash,
                   valid_type: described_class.valid_type

  no_data_setup = -> do
    tags valid_type.classify
    security [ apiToken: [] ]
    produces CONTENT_TYPE
  end
  data_setup = -> do
    instance_exec &no_data_setup
    consumes CONTENT_TYPE
    parameter name: :params, in: :body, schema: json_schema_hash
  end

  let(:id) { @resource.uuid }

  context 'with valid Accept and API token headers' do
    let(:Accept)                                         { CONTENT_TYPE }
    let(Api::JsonApiController::API_TOKEN_HEADER.to_sym) { @application.token }

    path '/api/resources' do
      get 'List Resources created by the current application' do
        instance_exec &no_data_setup
        parameter name: :'filter[query]',    in: :query, type: :string, required: false
        parameter name: :'filter[language]', in: :query, type: :string, required: false

        context 'with no filter param' do
          response 200, 'success' do
            schema json_schema_hash

            run_test! do |response|
              expect(response.body_hash).to eq JSON.parse(
                Api::V1::ResourceSerializer.new([ @resource ]).serialized_json
              ).deep_symbolize_keys
            end
          end
        end

        context 'with a filter param' do
          before(:all) do
            DatabaseCleaner.start

            simple  = FactoryBot.create :language, name: 'simple'
            english = FactoryBot.create :language, name: 'english'

            all_queries = [ 'lorem', 'jumps', 'jump', 'jumping', 'jumped' ]
            [ @resource ] + 10.times.map do
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

            response 200, 'success' do
              schema json_schema_hash

              let!(:expected_response) do
                JSON.parse(
                  Api::V1::ResourceSerializer.new(
                    @application.resources.search('lorem', 'simple').with_pg_search_highlight
                  ).serialized_json
                ).deep_symbolize_keys
              end
              before do
                expect(Resource).to receive(:search).with('lorem', 'simple').and_call_original
              end

              run_test! { |response| expect(response.body_hash).to eq expected_response }
            end
          end

          context 'with a language param' do
            let(:'filter[query]')    { 'jumps' }
            let(:'filter[language]') { 'english' }

            response 200, 'success' do
              schema json_schema_hash

              let!(:expected_response) do
                JSON.parse(
                  Api::V1::ResourceSerializer.new(
                    @application.resources.search('jumps', 'english').with_pg_search_highlight
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

      post 'Create a new Resource with a random Id' do
        instance_exec &data_setup

        context 'when the provided uri does not yet exist' do
          let(:uri)    { Faker::Internet.url }
          let(:params) do
            Api::V1::ResourceSerializer.new(@resource).serializable_hash.tap do |hash|
              hash[:data].delete(:id)
              hash[:data][:attributes][:uri] = uri
            end
          end
          let(:expected_response) do
            JSON.parse(params.to_json).deep_symbolize_keys.tap do |hash|
              hash[:data][:id] = kind_of(String)
            end
          end

          response 201, 'resource created' do
            schema json_schema_hash

            run_test! { |response| expect(response.body_hash).to match expected_response }
          end
        end

        context 'when the provided uri already exists' do
          let(:params) do
            Api::V1::ResourceSerializer.new(@resource).serializable_hash.tap do |hash|
              hash[:data].delete(:id)
            end
          end

          response 409, 'resource uri already exists' do
            schema json_schema_hash

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

    path '/api/resources/{id}' do
      parameter name: :id, in: :path, type: :string, description: "The Resource object's Id"

      get 'View the Resource with the given Id' do
        instance_exec &no_data_setup

        context 'when the resource was created by the current application' do
          response 200, 'success' do
            schema json_schema_hash

            run_test! do |response|
              expect(response.body_hash).to eq JSON.parse(
                Api::V1::ResourceSerializer.new(@resource).serialized_json
              ).deep_symbolize_keys
            end
          end
        end
      end

      post 'Create a new Resource with the given Id' do
        instance_exec &data_setup

        context 'when the resource does not exist or was created by a different application' do
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

          let(:params) do
            Api::V1::ResourceSerializer.new(@resource).serializable_hash.tap do |hash|
              hash[:data][:relationships][:application][:data][:id] = @application.uuid
              hash[:data][:relationships][:application_user][:data] = {
                id: @application_user.uuid, type: :application_user
              }
            end
          end

          context 'when the provided uri does not yet exist' do
            response 201, 'Resource created' do
              schema json_schema_hash

              run_test! do |response|
                expect(response.body_hash).to eq JSON.parse(params.to_json).deep_symbolize_keys
              end
            end
          end

          context 'when the provided uri already exists' do
            before { FactoryBot.create :resource, application: @application, uri: @resource.uri }

            response 409, 'resource uri already exists' do
              schema json_schema_hash

              run_test! do |response|
                expect(response.errors.first[:status]).to eq '409'
                expect(response.errors.first[:code]).to eq 'uri_has_already_been_taken'
                expect(response.errors.first[:title]).to eq 'Resource Invalid'
                expect(response.errors.first[:detail]).to eq 'Uri has already been taken.'
              end
            end
          end
        end

        context 'when the resource already exists' do
          let(:params) { Api::V1::ResourceSerializer.new(@resource).serializable_hash }

          response 409, 'resource uuid already exists' do
            schema json_schema_hash

            run_test! do |response|
              expect(response.errors.first[:status]).to eq '409'
              expect(response.errors.first[:code]).to eq 'uuid_has_already_been_taken'
              expect(response.errors.first[:title]).to eq 'Resource Invalid'
              expect(response.errors.first[:detail]).to eq 'Uuid has already been taken.'
            end
          end
        end

        [ :put, :patch ].each do |verb|
          public_send verb, 'Update the Resource with the given Id' do
            instance_exec &data_setup

            after(:all) { @resource.reload }

            let(:params) do
              Api::V1::ResourceSerializer.new(@other_application_resource)
                                         .serializable_hash
                                         .tap do |hash|
                hash[:data][:id] = @resource.uuid
                hash[:data][:relationships][:application][:data][:id] = @application.uuid
                hash[:data][:relationships][:application_user][:data] = nil
              end
            end

            context 'when the resource was created by the current application' do
              response 200, 'resource updated' do
                schema json_schema_hash

                run_test! do |response|
                  expect(response.body_hash).to eq JSON.parse(params.to_json).deep_symbolize_keys
                end
              end
            end
          end
        end

        delete 'Delete the Resource with the given Id' do
          instance_exec &no_data_setup

          after(:all) { @resource.reload }

          context 'when the resource was created by the current application' do
            response 200, 'resource deleted' do
              schema json_schema_hash

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
end
