require 'rails_helper'

RSpec.shared_examples 'json api controller errors' do |collection_actions: nil,
                                                       member_actions: nil,
                                                       params_proc: nil,
                                                       api_token_proc: nil|
  collection_actions ||= [
    [ :get , :index  ],
    [ :post, :create ]
  ]
  member_actions ||= [
    [ :get   , :show    ],
    [ :post  , :create  ],
    [ :put   , :update  ],
    [ :patch , :update  ],
    [ :delete, :destroy ]
  ]
  actions = collection_actions + member_actions
  params_proc ||= -> { {} }
  api_token_proc ||= -> { FactoryBot.create(:application).token }

  let(:uuid)      { SecureRandom.uuid }
  let(:params)    { instance_exec &params_proc }
  let(:api_token) { instance_exec &api_token_proc }

  context 'without an API token' do
    actions.each do |method, action|
      context "#{method.upcase} ##{action}" do
        let(:action_params) do
          [ :index, :search ].include?(action) ? params : params.merge(uuid: uuid)
        end
        before       { public_send method, action, params: action_params, format: :json }
        let(:error)  { response.body_hash[:errors].first }

        it 'renders a JSON API 400 error' do
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
    before { request.headers[described_class::API_TOKEN_HEADER] = SecureRandom.hex(32) }

    actions.each do |method, action|
      context "#{method.upcase} ##{action}" do
        let(:action_params) do
          [ :index, :search ].include?(action) ? params : params.merge(uuid: uuid)
        end
        before       { public_send method, action, params: action_params, format: :json }
        let(:error)  { response.body_hash[:errors].first }

        it 'returns a JSON API 403 error' do
          expect(error[:status]).to eq '403'
          expect(error[:code]).to eq 'invalid_api_token'
          expect(error[:title]).to eq 'Invalid API Token'
          expect(error[:detail]).to eq(
            "The API token provided in the #{described_class::API_TOKEN_HEADER} header is invalid."
          )
        end
      end
    end
  end

  context 'with a valid API token' do
    before { request.headers[described_class::API_TOKEN_HEADER] = api_token }

    context 'with no data member' do
      member_actions.each do |method, action|
        context "#{method.upcase} ##{action}" do
          let(:action_params) do
            [ :index, :search ].include?(action) ? params : params.merge(uuid: uuid)
          end
          before       { public_send method, action, params: action_params, format: :json }
          let(:error)  { response.body_hash[:errors].first }

          it 'returns a JSON API 400 error' do
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
        let(:action_params) { params.merge(uuid: uuid, data: { attributes: { test: true } }) }

        member_actions.each do |method, action|
          context "#{method.upcase} ##{action}" do
            before      { public_send method, action, params: action_params, format: :json }
            let(:error) { response.body_hash[:errors].first }

            it 'returns a JSON API 400 error' do
              expect(error[:status]).to eq '400'
              expect(error[:code]).to eq 'missing_type'
              expect(error[:title]).to eq 'Missing Type'
              expect(error[:detail]).to eq 'The type member is required by this API endpoint.'
            end
          end
        end
      end

      context 'with an invalid type member' do
        let(:action_params) { params.merge(uuid: uuid, data: { type: 'object' }) }

        member_actions.each do |method, action|
          context "#{method.upcase} ##{action}" do
            before      { public_send method, action, params: action_params, format: :json }
            let(:error) { response.body_hash[:errors].first }

            it 'returns a JSON API 409 error' do
              expect(error[:status]).to eq '409'
              expect(error[:code]).to eq 'invalid_type'
              expect(error[:title]).to eq 'Invalid Type'
              expect(error[:detail]).to eq(
                'The type provided is not supported by this API endpoint.'
              )
            end
          end
        end
      end

      context 'with a valid type member' do
        context 'with no id member' do
          let(:action_params) do
            params.merge(uuid: uuid, data: { type: described_class.valid_type })
          end

          member_actions.each do |method, action|
            context "#{method.upcase} ##{action}" do
              before      { public_send method, action, params: action_params, format: :json }
              let(:error) { response.body_hash[:errors].first }

              it 'returns a JSON API 400 error' do
                expect(error[:status]).to eq '400'
                expect(error[:code]).to eq 'missing_id'
                expect(error[:title]).to eq 'Missing Id'
                expect(error[:detail]).to eq 'The id member is required by this API endpoint.'
              end
            end
          end
        end

        context 'with an id that does not match the url uuid' do
          let(:action_params) do
            params.merge(
              uuid: uuid, data: { type: described_class.valid_type, id: SecureRandom.uuid }
            )
          end

          member_actions.each do |method, action|
            context "#{method.upcase} ##{action}" do
              before      { public_send method, action, params: action_params, format: :json }
              let(:error) { response.body_hash[:errors].first }

              it 'returns a JSON API 409 error' do
                expect(error[:status]).to eq '409'
                expect(error[:code]).to eq 'invalid_id'
                expect(error[:title]).to eq 'Invalid Id'
                expect(error[:detail]).to eq 'The id provided did not match the API endpoint URL.'
              end
            end
          end
        end

        context 'with an id that does not exist' do
          let(:action_params) do
            params.merge uuid: uuid, data: { type: described_class.valid_type, id: uuid }
          end

          member_actions.reject { |method, action| action == :create }.each do |method, action|
            context "#{method.upcase} ##{action}" do
              before      { public_send method, action, params: action_params, format: :json }
              let(:error) { response.body_hash[:errors].first }

              it 'returns a JSON API 404 error' do
                expect(error[:status]).to eq '404'
                expect(error[:code]).to eq 'not_found'
                expect(error[:title]).to eq 'Not Found'
                expect(error[:detail]).to eq(
                  'An object matching the type and id provided could not be found.'
                )
              end
            end
          end
        end
      end
    end
  end
end
