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
      it 'renders all resources created by the current application' do
        get :index, format: :json

        expect(response.body).to eq(
          Api::V1::ResourceSerializer.new([ @resource ]).serialized_json
        )
      end
    end

    context '#show' do
      before { get :show, params: { uuid: resource.uuid }, format: :json }

      context 'when the resource was created by the current application' do
        let(:resource) { @resource }

        it 'renders the given resource' do
          expect(response.body).to eq(
            Api::V1::ResourceSerializer.new(@resource).serialized_json
          )
        end
      end

      context 'when the resource was created by a different application' do
        let(:resource) { @other_application_resource }
        let(:error)    { response.errors.first }

        it 'returns a JSON API 404 error' do
          expect(error[:status]).to eq '404'
          expect(error[:code]).to eq 'not_found'
          expect(error[:title]).to eq 'Not Found'
          expect(error[:detail]).to eq "Couldn't find Resource"
        end
      end
    end

    xcontext '#create' do
      before(:all) do
        DatabaseCleaner.start

        @resource.destroy
      end
      after(:all)  { DatabaseCleaner.clean }

      context 'when the id is not provided' do
        let(:params) do
          Api::V1::ResourceSerializer.new(@resource).serializable_hash.tap do |hash|
            hash[:data].delete(:id)
          end
        end
        before { post :create, params: params, format: :json }

        it 'creates and renders the resource with a random id' do
          expect(response.body_hash).to match JSON.parse(
            Api::V1::ResourceSerializer.new(@resource).serializable_hash.tap do |hash|
              hash[:data][:id] = kind_of(String)
            end.to_json
          ).deep_symbolize_keys
        end
      end

      context 'when the id is provided' do
        let(:params) { Api::V1::ResourceSerializer.new(@resource).serializable_hash }
        before { post :create, params: params.merge(uuid: @resource.uuid), format: :json }

        context 'when the resource does not exist' do
          let(:resource) { @resource }

          it 'creates and renders the resource with the provided id' do
            expect(response.body_hash).to eq JSON.parse(
              Api::V1::ResourceSerializer.new(@resource).serialized_json
            ).deep_symbolize_keys
          end
        end

        context 'when the resource already exists' do
          let(:error) { response.errors.first }

          it 'returns a JSON API 409 error' do
            expect(error[:status]).to eq '409'
            expect(error[:code]).to eq 'already_exists'
            expect(error[:title]).to eq 'Already Exists'
            expect(error[:detail]).to eq(
              'An object matching the type and id provided already exists.'
            )
          end
        end
      end
    end
  end
end
