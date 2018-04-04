require 'swagger_helper'

RSpec.describe Api::V1::MetadatasController, type: :request do

  before(:all) do
    @metadata = FactoryBot.create :metadata
    @resource = @metadata.resource
    @application = @metadata.application
    @other_application_metadata = FactoryBot.create :metadata
  end

  include_examples 'json api request errors',
                   application_proc: -> { @application },
                   base_path_template: '/api/resources/{resource_id}/metadatas',
                   json_schema_hash: Api::V1::MetadataSerializer.json_schema_hash,
                   valid_type: described_class.valid_type,
                   id_scope: 'Resource',
                   path_params_proc: -> do
                     parameter name: :resource_id, in: :path, type: :string,
                               description: "The associated Resource's Id"

                     let(:resource_id) { @resource.uuid }
                   end

  context 'with valid Accept and API token headers' do
    let(:headers) do
      { 'Accept' => CONTENT_TYPE, described_class::API_TOKEN_HEADER => @application.token }
    end

    context 'GET #index' do
      let(:perform_request) do
        get api_resource_metadatas_path(@resource.uuid), headers: headers, as: :json
      end

      it 'renders all metadatas created by the current application for the given resource' do
        expect { perform_request }.not_to change { Metadata.count }

        expect(response).to be_ok
        expect(response.body_hash).to eq JSON.parse(
          Api::V1::MetadataSerializer.new([ @metadata ]).serialized_json
        ).deep_symbolize_keys
      end
    end

    context 'GET #show' do
      let(:perform_request) do
        get api_resource_metadata_path(@resource.uuid, @metadata.uuid), headers: headers, as: :json
      end

      context 'when the metadata was created by the current application' do
        let(:metadata) { @metadata }

        it 'renders the provided metadata' do
          expect { perform_request }.not_to change { Metadata.count }

          expect(response).to be_ok
          expect(response.body_hash).to eq JSON.parse(
            Api::V1::MetadataSerializer.new(@metadata).serialized_json
          ).deep_symbolize_keys
        end
      end
    end

    context 'POST #create' do
      context 'when the id is not provided' do
        let(:perform_request) do
          post api_resource_metadatas_path(@resource.uuid),
               params: params,
               headers: headers,
               as: :json
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
            post api_resource_metadata_path(@resource.uuid, @other_application_metadata.uuid),
                 params: params.merge(
                   resource_uuid: @resource.uuid, uuid: @other_application_metadata.uuid
                 ),
                 headers: headers,
                 as: :json
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
            post api_resource_metadata_path(@resource.uuid, @metadata.uuid),
                 params: params.merge(resource_uuid: @resource.uuid, uuid: @metadata.uuid),
                 headers: headers,
                 as: :json
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
          public_send verb,
                      api_resource_metadata_path(@resource.uuid, @metadata.uuid),
                      params: params.merge(uuid: @metadata.uuid),
                      headers: headers,
                      as: :json
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
        delete api_resource_metadata_path(@resource.uuid, @metadata.uuid),
               headers: headers,
               as: :json
      end

      context 'when the metadata was created by the current application' do
        let(:metadata) { @metadata }

        it 'deletes and renders the provided metadata' do
          expect { perform_request }.to change { Metadata.count }.by(-1)

          expect(response).to be_ok
          expect(response.body_hash).to eq JSON.parse(
            Api::V1::MetadataSerializer.new(@metadata).serialized_json
          ).deep_symbolize_keys
        end
      end
    end
  end
end
