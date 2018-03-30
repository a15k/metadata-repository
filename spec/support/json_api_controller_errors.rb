require 'rails_helper'

RSpec.shared_examples 'json api controller errors' do |
    extra_no_data_requests: [],
    extra_data_requests: [],
    extra_collection_actions: [],
    extra_params_proc: -> { {} },
    application_proc: -> { FactoryBot.create(:application) }
  |
  no_data_requests = [
    [ :get   , :index   ],
    [ :get   , :show    ],
    [ :delete, :destroy ]
  ] + extra_no_data_requests
  data_requests = [
    [ :post  , :create  ],
    [ :put   , :update  ],
    [ :patch , :update  ]
  ] + extra_data_requests
  collection_actions = [ :index ] + extra_collection_actions
  requests = no_data_requests + data_requests

  let(:uuid)         { SecureRandom.uuid }
  let(:extra_params) { instance_exec &extra_params_proc }
  let(:application)  { instance_exec &application_proc }
  let(:api_token)    { application.token }
  let(:error)        { response.errors.first }

  context 'without an API token' do
    requests.each do |method, action|
      context "#{method.upcase} ##{action}" do
        let(:params) do
          collection_actions.include?(action) ? extra_params : extra_params.merge(uuid: uuid)
        end
        before       { public_send method, action, params: params, format: :json }

        it 'renders a JSON API 400 error' do
          expect(response).to be_bad_request
          expect(error[:status]).to eq '400'
          expect(error[:code]).to eq 'missing_api_token'
          expect(error[:title]).to eq 'Missing API Token'
          expect(error[:detail]).to eq(
            "No API token was provided in the #{described_class::API_TOKEN_HEADER} header."
          )
        end
      end
    end
  end

  context 'with an invalid API token' do
    let(:api_token) { SecureRandom.hex(32) }
    before { request.headers[described_class::API_TOKEN_HEADER] = api_token }

    requests.each do |method, action|
      context "#{method.upcase} ##{action}" do
        let(:params) do
          collection_actions.include?(action) ? extra_params : extra_params.merge(uuid: uuid)
        end
        before       { public_send method, action, params: params, format: :json }
        let(:error)  { response.body_hash[:errors].first }

        it 'returns a JSON API 403 error' do
          expect(response).to be_forbidden
          expect(error[:status]).to eq '403'
          expect(error[:code]).to eq 'invalid_api_token'
          expect(error[:title]).to eq 'Invalid API Token'
          expect(error[:detail]).to eq(
            "The API token provided in the #{described_class::API_TOKEN_HEADER
            } header (#{api_token}) is invalid."
          )
        end
      end
    end
  end

  context 'with a valid API token' do
    before { request.headers[described_class::API_TOKEN_HEADER] = api_token }

    context 'with no data member' do
      data_requests.each do |method, action|
        context "#{method.upcase} ##{action}" do
          let(:params) { extra_params.merge(uuid: uuid) }
          before       { public_send method, action, params: params, format: :json }

          it 'returns a JSON API 400 error' do
            expect(response).to be_bad_request
            expect(error[:status]).to eq '400'
            expect(error[:code]).to eq 'missing_data'
            expect(error[:title]).to eq 'Missing Data'
            expect(error[:detail]).to eq 'The data member is required by this API endpoint.'
          end
        end
      end
    end

    context 'with a data member' do
      context 'with no type member' do
        let(:params) { extra_params.merge(uuid: uuid, data: { attributes: { test: true } }) }

        data_requests.each do |method, action|
          context "#{method.upcase} ##{action}" do
            before      { public_send method, action, params: params, format: :json }

            it 'returns a JSON API 400 error' do
              expect(response).to be_bad_request
              expect(error[:status]).to eq '400'
              expect(error[:code]).to eq 'missing_type'
              expect(error[:title]).to eq 'Missing Type'
              expect(error[:detail]).to eq 'The type member is required by this API endpoint.'
            end
          end
        end
      end

      context 'with an invalid type' do
        let(:type)   { 'object' }
        let(:params) { extra_params.merge(uuid: uuid, data: { type: type }) }

        data_requests.each do |method, action|
          context "#{method.upcase} ##{action}" do
            before      { public_send method, action, params: params, format: :json }
            let(:error) { response.body_hash[:errors].first }

            it 'returns a JSON API 409 error' do
              expect(response.status).to eq 409
              expect(error[:status]).to eq '409'
              expect(error[:code]).to eq 'invalid_type'
              expect(error[:title]).to eq 'Invalid Type'
              expect(error[:detail]).to eq(
                "The type provided (#{type}) is not the one supported by this API endpoint (#{
                controller.class.valid_type})."
              )
            end
          end
        end
      end

      context 'with a valid type' do
        let(:type)   { described_class.valid_type }

        context 'with no id member' do
          let(:params) { extra_params.merge(uuid: uuid, data: { type: type }) }

          data_requests.reject { |method, action| action == :create }.each do |method, action|
            context "#{method.upcase} ##{action}" do
              before      { public_send method, action, params: params, format: :json }

              it 'returns a JSON API 400 error' do
                expect(response).to be_bad_request
                expect(error[:status]).to eq '400'
                expect(error[:code]).to eq 'missing_id'
                expect(error[:title]).to eq 'Missing Id'
                expect(error[:detail]).to eq 'The id member is required by this API endpoint.'
              end
            end
          end
        end

        context 'with an id that does not match the url uuid' do
          let(:id)     { SecureRandom.uuid }
          let(:params) do
            extra_params.merge uuid: uuid, data: { type: type, id: id }
          end

          data_requests.each do |method, action|
            context "#{method.upcase} ##{action}" do
              before      { public_send method, action, params: params, format: :json }

              it 'returns a JSON API 409 error' do
                expect(response.status).to eq 409
                expect(error[:status]).to eq '409'
                expect(error[:code]).to eq 'invalid_id'
                expect(error[:title]).to eq 'Invalid Id'
                expect(error[:detail]).to eq(
                  "The id provided (#{id}) did not match the id in the API endpoint URL (#{uuid})."
                )
              end
            end
          end
        end

        context 'with an id that does not exist' do
          let(:params) { extra_params.merge uuid: uuid, data: { type: type, id: uuid } }

          data_requests.reject { |method, action| action == :create }.each do |method, action|
            context "#{method.upcase} ##{action}" do
              before      { public_send method, action, params: params, format: :json }

              it 'returns a JSON API 404 error' do
                expect(response).to be_not_found
                expect(error[:status]).to eq '404'
                expect(error[:code]).to eq 'not_found'
                expect(error[:title]).to eq 'Not Found'
                expect(error[:detail]).to eq "Couldn't find #{type.humanize}"
              end
            end
          end
        end

        context 'with a valid id' do
          let(:id)     { FactoryBot.create(type).uuid }

          context 'with a relationship' do
            context 'with no data member' do
              let(:params) do
                extra_params.merge uuid: id, data: {
                  type: type,
                  id: id,
                  relationships: { application: { test: true } }
                }
              end

              data_requests.each do |method, action|
                context "#{method.upcase} ##{action}" do
                  before { public_send method, action, params: params, format: :json }

                  it 'returns a JSON API 400 error' do
                    expect(response).to be_bad_request
                    expect(error[:status]).to eq '400'
                    expect(error[:code]).to eq 'missing_data'
                    expect(error[:title]).to eq 'Missing Data'
                    expect(error[:detail]).to eq 'The data member is required by this API endpoint.'
                  end
                end
              end
            end

            context 'with a data member' do
              context 'with no type member' do
                let(:params) do
                  extra_params.merge uuid: id, data: {
                    type: type,
                    id: id,
                    relationships: { application: { data: { test: true } } }
                  }
                end

                data_requests.each do |method, action|
                  context "#{method.upcase} ##{action}" do
                    before { public_send method, action, params: params, format: :json }

                    it 'returns a JSON API 400 error' do
                      expect(response).to be_bad_request
                      expect(error[:status]).to eq '400'
                      expect(error[:code]).to eq 'missing_type'
                      expect(error[:title]).to eq 'Missing Type'
                      expect(error[:detail]).to eq(
                        'The type member is required by this API endpoint.'
                      )
                    end
                  end
                end
              end

              context 'with an invalid type' do
                let(:params) do
                  extra_params.merge uuid: id, data: {
                    type: type,
                    id: id,
                    relationships: { application: { data: { type: 'resource' } } }
                  }
                end

                data_requests.each do |method, action|
                  context "#{method.upcase} ##{action}" do
                    before { public_send method, action, params: params, format: :json }

                    it 'returns a JSON API 409 error' do
                      expect(response.status).to eq 409
                      expect(error[:status]).to eq '409'
                      expect(error[:code]).to eq 'invalid_application_type'
                      expect(error[:title]).to eq 'Invalid Application Type'
                      expect(error[:detail]).to eq(
                        'The type provided for the application object (resource) is invalid.'
                      )
                    end
                  end
                end
              end

              context 'with a valid type' do
                context 'with no id member' do
                  let(:params) do
                    extra_params.merge uuid: id, data: {
                      type: type,
                      id: id,
                      relationships: { application: { data: { type: 'application' } } }
                    }
                  end

                  data_requests.each do |method, action|
                    context "#{method.upcase} ##{action}" do
                      before { public_send method, action, params: params, format: :json }

                      it 'returns a JSON API 400 error' do
                        expect(response).to be_bad_request
                        expect(error[:status]).to eq '400'
                        expect(error[:code]).to eq 'missing_id'
                        expect(error[:title]).to eq 'Missing Id'
                        expect(error[:detail]).to eq(
                          'The id member is required by this API endpoint.'
                        )
                      end
                    end
                  end
                end
              end
            end
          end

          context 'with an application relationship with a data member' +
                  ' with a valid type with a forbidden id' do
            let(:params) do
              extra_params.merge uuid: id, data: {
                type: type,
                id: id,
                relationships: {
                  application: { data: { type: 'application', id: SecureRandom.uuid } }
                }
              }
            end

            data_requests.each do |method, action|
              context "#{method.upcase} ##{action}" do
                before { public_send method, action, params: params, format: :json }

                it 'returns a JSON API 403 error' do
                  expect(response).to be_forbidden
                  expect(error[:status]).to eq '403'
                  expect(error[:code]).to eq 'forbidden_application_id'
                  expect(error[:title]).to eq 'Forbidden Application Id'
                  expect(error[:detail]).to eq(
                    "You are only allowed to provide your own application id (#{application.uuid})."
                  )
                end
              end
            end
          end
        end
      end
    end
  end
end
