require 'rails_helper'

RSpec.describe Api::V1::ResourcesController, type: :controller do

  before(:all) do
    @resource = FactoryBot.create :resource
    @application = @resource.application
    @other_application_resource = FactoryBot.create :resource
  end

  include_examples 'json api controller errors', extra_no_data_requests: [ [ :get, :search ] ],
                                                 extra_collection_actions: [ :search ]

  context 'with a valid API token' do
    before { request.headers[described_class::API_TOKEN_HEADER] = @application.token }

    context '#index' do
      let(:perform_request) { get :index, as: :json }
      it 'renders all resources created by the current application' do
        expect { perform_request }.not_to change { Resource.count }

        expect(response.body).to eq(
          Api::V1::ResourceSerializer.new([ @resource ]).serialized_json
        )
      end
    end

    context '#show' do
      let(:perform_request) { get :show, params: { uuid: resource.uuid }, as: :json }

      context 'when the resource was created by the current application' do
        let(:resource) { @resource }

        it 'renders the given resource' do
          expect { perform_request }.not_to change { Resource.count }

          expect(response.body).to eq(
            Api::V1::ResourceSerializer.new(@resource).serialized_json
          )
        end
      end

      context 'when the resource was created by a different application' do
        let(:resource) { @other_application_resource }
        let(:error)    { response.errors.first }

        it 'returns a JSON API 404 error' do
          expect { perform_request }.not_to change { Resource.count }

          expect(error[:status]).to eq '404'
          expect(error[:code]).to eq 'not_found'
          expect(error[:title]).to eq 'Not Found'
          expect(error[:detail]).to eq "Couldn't find Resource"
        end
      end
    end

    context '#create' do
      context 'when the id is not provided' do
        let(:perform_request) { post :create, params: params, as: :json }

        context 'when the provided uri does not yet exist' do
          let(:uri)    { Faker::Internet.url }
          let(:params) do
            Api::V1::ResourceSerializer.new(@resource).serializable_hash.tap do |hash|
              hash[:data].delete(:id)
              hash[:data][:attributes][:uri] = uri
            end
          end

          it 'creates and renders the resource with a random id' do
            expect { perform_request }.to change { Resource.count }.by(1)

            expect(response.body_hash).to match(
              JSON.parse(
                Api::V1::ResourceSerializer.new(@resource).serialized_json
              ).deep_symbolize_keys.tap do |hash|
                hash[:data][:id] = kind_of(String)
                hash[:data][:attributes][:uri] = uri
              end
            )
          end
        end

        context 'when the provided uri already exists' do
          let(:params) do
            Api::V1::ResourceSerializer.new(@resource).serializable_hash.tap do |hash|
              hash[:data].delete(:id)
            end
          end
          let(:error) { @response.errors.first }

          it 'returns a JSON API 409 error' do
            expect { perform_request }.not_to change { Resource.count }

            expect(error[:status]).to eq '409'
            expect(error[:code]).to eq 'uri_has_already_been_taken'
            expect(error[:title]).to eq 'Resource Invalid'
            expect(error[:detail]).to eq 'Uri has already been taken.'
          end
        end
      end

      context 'when the id is provided' do
        let(:params) { Api::V1::ResourceSerializer.new(@resource).serializable_hash }
        let(:perform_request) do
          post :create, params: params.merge(uuid: @resource.uuid), as: :json
        end

        context 'when the resource does not exist' do
          before { @resource.destroy! }

          it 'creates and renders the resource with the provided id' do
            expect { perform_request }.to change { Resource.count }.by(1)

            expect(response.body_hash).to eq JSON.parse(
              Api::V1::ResourceSerializer.new(@resource).serialized_json
            ).deep_symbolize_keys
          end
        end

        context 'when the resource already exists' do
          let(:error) { @response.errors.first }

          it 'returns a JSON API 409 error' do
            expect { perform_request }.not_to change { Resource.count }

            expect(error[:status]).to eq '409'
            expect(error[:code]).to eq 'uuid_has_already_been_taken'
            expect(error[:title]).to eq 'Resource Invalid'
            expect(error[:detail]).to eq "Uuid has already been taken."
          end
        end
      end
    end
  end
end
