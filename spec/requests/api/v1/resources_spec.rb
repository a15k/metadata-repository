require 'rails_helper'

RSpec.describe Api::V1::ResourcesController, type: :request do

  before(:all) do
    @resource = FactoryBot.create :resource
    @application = @resource.application
    @other_application_resource = FactoryBot.create :resource
  end

  include_examples 'json api request errors',
                   application_proc: -> { @application },
                   base_url_proc: -> { '/api/resources' }

  context 'with valid Accept and API token headers' do
    let(:headers) do
      { 'Accept' => CONTENT_TYPE, described_class::API_TOKEN_HEADER => @application.token }
    end

    context 'GET #index' do
      let(:perform_request) { get api_resources_path, headers: headers, as: :json }

      it 'renders all resources created by the current application' do
        expect { perform_request }.not_to change { Resource.count }

        expect(response).to be_ok
        expect(response.body_hash).to eq JSON.parse(
          Api::V1::ResourceSerializer.new([ @resource ]).serialized_json
        ).deep_symbolize_keys
      end

      context 'with the filter param' do
        before(:all) do
          DatabaseCleaner.start

          simple  = FactoryBot.create :language, name: 'simple'
          english = FactoryBot.create :language, name: 'english'

          all_queries = [ 'lorem', 'jumps', 'jump' ]
          resources = 10.times.map do
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
        after(:all)  { DatabaseCleaner.clean }

        it "passes the :query param to Resource.search, defaulting to the 'simple' configuration" do
          expected_response = JSON.parse(
            Api::V1::ResourceSerializer.new(
              @application.resources.search('lorem', 'simple').with_pg_search_highlight
            ).serialized_json
          ).deep_symbolize_keys
          expect(Resource).to receive(:search).with('lorem', 'simple').and_call_original

          expect do
            get api_resources_path(filter: { query: 'lorem' }), headers: headers, as: :json
          end.not_to change { Resource.count }

          expect(response.body_hash).to eq expected_response
        end

        it 'allows the search configuration to be specified using the :language param' do
          expected_response = JSON.parse(
            Api::V1::ResourceSerializer.new(
              @application.resources.search('jumps', 'english').with_pg_search_highlight
            ).serialized_json
          ).deep_symbolize_keys
          expect(Resource).to receive(:search).with('jumps', 'english').and_call_original

          expect do
            get api_resources_path(filter: { query: 'jumps', language: 'english' }),
                headers: headers,
                as: :json
          end.not_to change { Resource.count }

          expect(response.body_hash).to eq expected_response
        end
      end
    end

    context 'GET #show' do
      let(:perform_request) { get api_resource_path(resource.uuid), headers: headers, as: :json }

      context 'when the resource was created by the current application' do
        let(:resource) { @resource }

        it 'renders the provided resource' do
          expect { perform_request }.not_to change { Resource.count }

          expect(response).to be_ok
          expect(response.body_hash).to eq JSON.parse(
            Api::V1::ResourceSerializer.new(@resource).serialized_json
          ).deep_symbolize_keys
        end
      end
    end

    context 'POST #create' do
      context 'when the id is not provided' do
        let(:perform_request) do
          post api_resources_path, params: params, headers: headers, as: :json
        end

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
            post api_resource_path(@other_application_resource.uuid),
                 params: params.merge(uuid: @other_application_resource.uuid),
                 headers: headers,
                 as: :json
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
            post api_resource_path(@resource.uuid),
                 params: params.merge(uuid: @resource.uuid),
                 headers: headers,
                 as: :json
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
          public_send verb, api_resource_path(@resource.uuid),
                            params: params.merge(uuid: @resource.uuid),
                            headers: headers,
                            as: :json
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
      let(:perform_request) do
        delete api_resource_path(@resource.uuid), headers: headers, as: :json
      end

      context 'when the resource was created by the current application' do
        let(:resource) { @resource }

        it 'deletes and renders the provided resource' do
          expect { perform_request }.to change { Resource.count }.by(-1)

          expect(response).to be_ok
          expect(response.body_hash).to eq JSON.parse(
            Api::V1::ResourceSerializer.new(@resource).serialized_json
          ).deep_symbolize_keys
        end
      end
    end
  end
end
