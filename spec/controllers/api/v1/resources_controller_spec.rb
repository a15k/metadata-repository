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

    context 'GET #index' do
      let(:perform_request) { get :index, as: :json }

      it 'renders all resources created by the current application' do
        expect { perform_request }.not_to change { Resource.count }

        expect(response).to be_ok
        expect(response.body).to eq(
          Api::V1::ResourceSerializer.new([ @resource ]).serialized_json
        )
      end
    end

    context 'GET #show' do
      let(:perform_request) { get :show, params: { uuid: resource.uuid }, as: :json }

      context 'when the resource was created by the current application' do
        let(:resource) { @resource }

        it 'renders the provided resource' do
          expect { perform_request }.not_to change { Resource.count }

          expect(response).to be_ok
          expect(response.body).to eq(
            Api::V1::ResourceSerializer.new(@resource).serialized_json
          )
        end
      end
    end

    context 'POST #create' do
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
          let(:expected_response) do
            JSON.parse(params.to_json).deep_symbolize_keys.tap do |hash|
              hash[:data][:id] = kind_of(String)
            end
          end

          it 'creates and renders the resource with a random id' do
            expect { perform_request }.to change { Resource.count }.by(1)

            expect(response).to be_ok
            expect(response.body_hash).to match expected_response
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
        context 'when the resource does not exist or was created by a different application' do
          let(:params) do
            Api::V1::ResourceSerializer.new(@other_application_resource)
                                       .serializable_hash
                                       .tap do |hash|
              hash[:data][:relationships][:application][:data][:id] = @application.uuid
              hash[:data][:relationships][:application_user][:data][:id] =
                @resource.application_user.uuid
            end
          end
          let(:perform_request) do
            post :create, params: params.merge(uuid: @other_application_resource.uuid), as: :json
          end

          it 'creates and renders the resource with the provided id' do
            expect { perform_request }.to change { Resource.count }.by(1)

            expect(response).to be_ok
            expect(response.body_hash).to eq JSON.parse(params.to_json).deep_symbolize_keys
          end
        end

        context 'when the resource already exists' do
          let(:params) { Api::V1::ResourceSerializer.new(@resource).serializable_hash }
          let(:perform_request) do
            post :create, params: params.merge(uuid: @resource.uuid), as: :json
          end
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

    [ :put, :patch ].each do |verb|
      context "#{verb.upcase} #update" do
        after(:all)  { @resource.reload }

        let(:params) do
          Api::V1::ResourceSerializer.new(@other_application_resource)
                                     .serializable_hash
                                     .tap do |hash|
            hash[:data][:id] = resource.uuid
            hash[:data][:relationships][:application][:data][:id] = @application.uuid
            hash[:data][:relationships][:application_user][:data] = nil
          end
        end
        let(:perform_request) do
          public_send verb, :update, params: params.merge(uuid: resource.uuid), as: :json
        end

        context 'when the resource was created by the current application' do
          let(:resource) { @resource }

          it 'updates and renders the provided resource' do
            expect { perform_request }.to  not_change { Resource.count }
                                      .and change     { @resource.reload.attributes }

            expect(response).to be_ok
            expect(response.body_hash).to eq JSON.parse(params.to_json).deep_symbolize_keys
          end
        end
      end
    end

    context 'DELETE #destroy' do
      let(:perform_request) { delete :destroy, params: { uuid: resource.uuid }, as: :json }

      context 'when the resource was created by the current application' do
        let(:resource) { @resource }

        it 'deletes and renders the provided resource' do
          expect { perform_request }.to change { Resource.count }.by(-1)

          expect(response).to be_ok
          expect(response.body).to eq(
            Api::V1::ResourceSerializer.new(@resource).serialized_json
          )
        end
      end
    end
  end
end
