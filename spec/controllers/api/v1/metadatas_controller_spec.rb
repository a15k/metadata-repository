require 'rails_helper'

RSpec.describe Api::V1::MetadatasController, type: :controller do

  before(:all) do
    @metadata = FactoryBot.create :metadata
    @resource = @metadata.resource
    @application = @metadata.application
    @other_application_metadata = FactoryBot.create :metadata
  end

  include_examples 'json api controller errors',
                   extra_params_proc: -> { { resource_uuid: @resource.uuid } },
                   application_proc: -> { @application }

  context 'with a valid API token' do
    before { request.headers[described_class::API_TOKEN_HEADER] = @application.token }

    context 'GET #index' do
      let(:perform_request) { get :index, params: { resource_uuid: @resource.uuid }, as: :json }

      it 'renders all metadatas created by the current application' do
        expect { perform_request }.not_to change { Metadata.count }

        expect(response).to be_ok
        expect(response.body).to eq(
          Api::V1::MetadataSerializer.new([ @metadata ]).serialized_json
        )
      end
    end

    context 'GET #show' do
      let(:perform_request) do
        get :show, params: { resource_uuid: @resource.uuid, uuid: metadata.uuid }, as: :json
      end

      context 'when the metadata was created by the current application' do
        let(:metadata) { @metadata }

        it 'renders the provided metadata' do
          expect { perform_request }.not_to change { Metadata.count }

          expect(response).to be_ok
          expect(response.body).to eq(
            Api::V1::MetadataSerializer.new(@metadata).serialized_json
          )
        end
      end
    end

    context 'POST #create' do
      context 'when the id is not provided' do
        let(:perform_request) do
          post :create, params: params.merge(resource_uuid: @resource.uuid), as: :json
        end

        let(:params) do
          Api::V1::MetadataSerializer.new(@metadata).serializable_hash.tap do |hash|
            hash[:data].delete(:id)
          end
        end
        let(:expected_response) do
          JSON.parse(params.to_json).deep_symbolize_keys.tap do |hash|
            hash[:data][:id] = kind_of(String)
          end
        end

        it 'creates and renders the metadata with a random id' do
          expect { perform_request }.to change { Metadata.count }.by(1)

          expect(response).to be_ok
          expect(response.body_hash).to match expected_response
        end
      end

      context 'when the id is provided' do
        context 'when the metadata does not exist or was created by a different application' do
          let(:params) do
            Api::V1::MetadataSerializer.new(@other_application_metadata)
                                       .serializable_hash
                                       .tap do |hash|
              hash[:data][:relationships][:application][:data][:id] = @application.uuid
              hash[:data][:relationships][:application_user][:data][:id] =
                @metadata.application_user.uuid
              hash[:data][:relationships][:resource][:data][:id] = @resource.uuid
            end
          end
          let(:perform_request) do
            post :create, params: params.merge(
              resource_uuid: @resource.uuid, uuid: @other_application_metadata.uuid
            ), as: :json
          end

          it 'creates and renders the metadata with the provided id' do
            expect { perform_request }.to change { Metadata.count }.by(1)

            expect(response).to be_ok
            expect(response.body_hash).to eq JSON.parse(params.to_json).deep_symbolize_keys
          end
        end

        context 'when the metadata already exists' do
          let(:params) { Api::V1::MetadataSerializer.new(@metadata).serializable_hash }
          let(:perform_request) do
            post :create, params: params.merge(
              resource_uuid: @resource.uuid, uuid: @metadata.uuid
            ), as: :json
          end
          let(:error) { @response.errors.first }

          it 'returns a JSON API 409 error' do
            expect { perform_request }.not_to change { Metadata.count }

            expect(error[:status]).to eq '409'
            expect(error[:code]).to eq 'uuid_has_already_been_taken'
            expect(error[:title]).to eq 'Metadata Invalid'
            expect(error[:detail]).to eq "Uuid has already been taken."
          end
        end
      end
    end

    [ :put, :patch ].each do |verb|
      context "#{verb.upcase} #update" do
        after(:all)  { @metadata.reload }

        let(:params) do
          Api::V1::MetadataSerializer.new(@other_application_metadata)
                                     .serializable_hash
                                     .tap do |hash|
            hash[:data][:id] = metadata.uuid
            hash[:data][:relationships][:application][:data][:id] = @application.uuid
            hash[:data][:relationships][:application_user][:data] = nil
            hash[:data][:relationships][:resource][:data][:id] = @resource.uuid
          end
        end
        let(:perform_request) do
          public_send verb, :update, params: params.merge(
            resource_uuid: @resource.uuid, uuid: metadata.uuid
          ), as: :json
        end

        context 'when the metadata was created by the current application' do
          let(:metadata) { @metadata }

          it 'updates and renders the provided metadata' do
            expect { perform_request }.to  not_change { Metadata.count }
                                      .and change     { @metadata.reload.attributes }

            expect(response).to be_ok
            expect(response.body_hash).to eq JSON.parse(params.to_json).deep_symbolize_keys
          end
        end
      end
    end

    context 'DELETE #destroy' do
      let(:perform_request) do
        delete :destroy, params: { resource_uuid: @resource.uuid, uuid: metadata.uuid }, as: :json
      end

      context 'when the metadata was created by the current application' do
        let(:metadata) { @metadata }

        it 'deletes and renders the provided metadata' do
          expect { perform_request }.to change { Metadata.count }.by(-1)

          expect(response).to be_ok
          expect(response.body).to eq(
            Api::V1::MetadataSerializer.new(@metadata).serialized_json
          )
        end
      end
    end
  end
end
