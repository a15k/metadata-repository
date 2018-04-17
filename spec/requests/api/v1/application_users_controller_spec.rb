require 'swagger_helper'
require_relative 'request_errors'

RSpec.describe Api::V1::ApplicationUsersController, type: :request do

  before(:all) do
    @application_user = FactoryBot.create :application_user
    @application = @application_user.application
    @other_application_application_user = FactoryBot.create :application_user
  end

  application_user_schema_reference = { '$ref': '#/definitions/application_user' }
  valid_type = described_class.valid_type
  it_behaves_like 'api v1 request errors',
                   application_proc: -> { @application },
                   base_path_template: '/application_users',
                   schema_reference: application_user_schema_reference,
                   valid_type: valid_type,
                   fully_scoped: true

  no_data_setup = ->(on) do
    tags valid_type.classify
    security [ apiToken: [] ]
    schemes 'https'
    produces CONTENT_TYPE
    parameter name: :id, in: :path, type: :string,
              description: "The ApplicationUser object's Id",
              schema: { type: :string, format: :uuid },
              example: SecureRandom.uuid if on == :member
  end
  data_setup = ->(on) do
    instance_exec on, &no_data_setup
    consumes CONTENT_TYPE
    parameter name: :application_user, in: :body, schema: application_user_schema_reference
  end

  create_collection_setup = -> do
    instance_exec :collection, &data_setup
    operationId 'createApplicationUser'
  end
  create_member_setup = -> do
    instance_exec :member, &data_setup
    operationId 'createApplicationUserWithId'
  end

  let(:id) { @application_user.uuid }

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

    path '/application_users' do
      get 'List ApplicationUsers created by the current application' do
        instance_exec :collection, &no_data_setup
        operationId 'getApplicationUsers'

        response 200, 'success' do
          schema application_user_schema_reference

          run_test! do |response|
            expect(response.body_hash).to eq JSON.parse(
              Api::V1::ApplicationUserSerializer.new([ @application_user ]).serialized_json
            ).deep_symbolize_keys
          end
        end
      end

      post 'Create a new ApplicationUser with a random Id' do
        instance_exec &create_collection_setup

        let(:application_user) do
          Api::V1::ApplicationUserSerializer.new(@application_user).serializable_hash.tap do |hash|
            hash[:data].delete(:id)
          end
        end
        let(:expected_response) do
          JSON.parse(application_user.to_json).deep_symbolize_keys.tap do |hash|
            hash[:data][:id] = kind_of(String)
          end
        end

        response 201, 'ApplicationUser created' do
          schema application_user_schema_reference

          run_test! { |response| expect(response.body_hash).to match expected_response }
        end
      end
    end

    path '/application_users/{id}' do
      get 'View the ApplicationUser with the given Id' do
        instance_exec :member, &no_data_setup
        operationId 'getApplicationUserWithId'

        context 'when the ApplicationUser was created by the current application' do
          response 200, 'success' do
            schema application_user_schema_reference

            run_test! do |response|
              expect(response.body_hash).to eq JSON.parse(
                Api::V1::ApplicationUserSerializer.new(@application_user).serialized_json
              ).deep_symbolize_keys
            end
          end
        end
      end

      context 'when the ApplicationUser does not exist or was created by a different application' do
        before(:all) do
          DatabaseCleaner.start

          other_application = FactoryBot.create :application
          @application_user.update_attribute :application, other_application
        end
        after(:all) do
          DatabaseCleaner.clean

          @application_user.reload
        end

        let(:application_user) do
          Api::V1::ApplicationUserSerializer.new(@application_user).serializable_hash.tap do |hash|
            hash[:data][:relationships][:application][:data][:id] = @application.uuid
          end
        end

        post 'Create a new ApplicationUser with the given Id' do
          instance_exec &create_member_setup

          response 201, 'ApplicationUser created' do
            schema application_user_schema_reference

            run_test! do |response|
              expect(response.body_hash).to(
                eq JSON.parse(application_user.to_json).deep_symbolize_keys
              )
            end
          end
        end
      end

      context 'when the ApplicationUser already exists' do
        let(:application_user) do
          Api::V1::ApplicationUserSerializer.new(@application_user).serializable_hash
        end

        post 'Create a new ApplicationUser with the given Id' do
          instance_exec &create_member_setup

          response 409, 'ApplicationUser uuid already exists' do
            schema application_user_schema_reference

            run_test! do |response|
              expect(response.errors.first[:status]).to eq '409'
              expect(response.errors.first[:code]).to eq 'uuid_has_already_been_taken'
              expect(response.errors.first[:title]).to eq 'ApplicationUser Invalid'
              expect(response.errors.first[:detail]).to eq 'Uuid has already been taken.'
            end
          end
        end
      end

      delete 'Delete the ApplicationUser with the given Id' do
        instance_exec :member, &no_data_setup
        operationId 'deleteApplicationUserWithId'

        after(:all) { @application_user.reload }

        context 'when the ApplicationUser was created by the current application' do
          response 200, 'ApplicationUser deleted' do
            schema application_user_schema_reference

            run_test! do |response|
              expect(response.body_hash).to eq JSON.parse(
                Api::V1::ApplicationUserSerializer.new(@application_user).serialized_json
              ).deep_symbolize_keys
            end
          end
        end
      end
    end
  end
end
