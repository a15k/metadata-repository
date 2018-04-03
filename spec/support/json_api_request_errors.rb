require 'rails_helper'

RSpec.shared_examples 'json api request errors' do |base_url_proc:, application_proc:|
  no_data_requests = [
    [ :get,    :collection ],
    [ :get,    :member     ],
    [ :delete, :member     ]
  ]
  data_requests = [
    [ :post,  :collection  ],
    [ :post,  :member      ],
    [ :put,   :member      ],
    [ :patch, :member      ]
  ]
  requests = no_data_requests + data_requests

  let!(:application)    { instance_exec &application_proc }
  let!(:base_url)       { instance_exec &base_url_proc }
  let(:collection_url)  { base_url }
  let(:member_url)      { "#{base_url}/#{uuid}" }
  let(:api_token)       { application.token }
  let(:url)             { on == :collection ? collection_url : member_url }
  let(:perform_request) { public_send verb, url, params: params, headers: headers, as: :json }

  let(:klass)           { described_class.valid_type.classify.constantize }
  let(:uuid)            { SecureRandom.uuid }
  let(:error)           { response.errors.first }

  context 'without an API token' do
    let(:headers) { { 'Accept' => CONTENT_TYPE } }

    requests.each do |verb, on|
      context "#{verb.upcase} ##{on}" do
        let(:verb)   { verb }
        let(:on)     { on }
        let(:params) { on == :collection ? {} : { uuid: uuid } }

        it 'renders a JSON API 400 error' do
          expect { perform_request }.not_to change { klass.count }

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
    let(:token)   { SecureRandom.hex(32) }
    let(:headers) do
      { 'Accept' => CONTENT_TYPE, described_class::API_TOKEN_HEADER => token }
    end

    requests.each do |verb, on|
      context "#{verb.upcase} ##{on}" do
        let(:verb)   { verb }
        let(:on)     { on }
        let(:params) { on == :collection ? {} : { uuid: uuid } }

        it 'returns a JSON API 403 error' do
          expect { perform_request }.not_to change { klass.count }

          expect(response).to be_forbidden
          expect(error[:status]).to eq '403'
          expect(error[:code]).to eq 'invalid_api_token'
          expect(error[:title]).to eq 'Invalid API Token'
          expect(error[:detail]).to eq(
            "The API token provided in the #{
            described_class::API_TOKEN_HEADER} header (#{token}) is invalid."
          )
        end
      end
    end
  end

  context 'with a valid API token' do
    let(:headers) do
      { 'Accept' => CONTENT_TYPE, described_class::API_TOKEN_HEADER => api_token }
    end

    context 'with no data member' do
      data_requests.each do |verb, on|
        context "#{verb.upcase} ##{on}" do
          let(:verb)   { verb }
          let(:on)     { on }
          let(:params) { on == :collection ? {} : { uuid: uuid } }

          it 'returns a JSON API 400 error' do
            expect { perform_request }.not_to change { klass.count }

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
        let(:params) { { data: { attributes: { test: true } } } }

        data_requests.each do |verb, on|
          context "#{verb.upcase} ##{on}" do
            let(:verb) { verb }
            let(:on)   { on }

            it 'returns a JSON API 400 error' do
              expect { perform_request }.not_to change { klass.count }

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
        let(:params) { { data: { type: type } } }

        data_requests.each do |verb, on|
          context "#{verb.upcase} ##{on}" do
            let(:verb) { verb }
            let(:on)   { on }

            it 'returns a JSON API 409 error' do
              expect { perform_request }.not_to change { klass.count }

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
          let(:params) { { data: { type: type } } }

          data_requests.reject { |verb, _| verb == :post }.each do |verb, on|
            context "#{verb.upcase} ##{on}" do
              let(:verb) { verb }
              let(:on)   { on }

              it 'returns a JSON API 400 error' do
                expect { perform_request }.not_to change { klass.count }

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
          let(:body_id) { SecureRandom.uuid }
          let(:params)  { { data: { type: type, id: body_id } } }

          data_requests.select { |_, on| on == :member }.each do |verb, on|
            context "#{verb.upcase} ##{on}" do
              let(:verb) { verb }
              let(:on)   { on }

              it 'returns a JSON API 409 error' do
                expect { perform_request }.not_to change { klass.count }

                expect(response.status).to eq 409
                expect(error[:status]).to eq '409'
                expect(error[:code]).to eq 'invalid_id'
                expect(error[:title]).to eq 'Invalid Id'
                expect(error[:detail]).to eq(
                  "The id provided in the request body (#{body_id
                  }) did not match the id provided in the API endpoint URL (#{uuid})."
                )
              end
            end
          end
        end

        context 'with an id that does not exist' do
          let(:params) { { data: { type: type, id: uuid } } }

          data_requests.reject { |verb, _| verb == :post }.each do |verb, on|
            context "#{verb.upcase} ##{on}" do
              let(:verb) { verb }
              let(:on)   { on }

              it 'returns a JSON API 404 error' do
                expect { perform_request }.not_to change { klass.count }

                expect(response).to be_not_found
                expect(error[:status]).to eq '404'
                expect(error[:code]).to eq 'not_found'
                expect(error[:title]).to eq 'Not Found'
                expect(error[:detail]).to eq "Couldn't find #{type.humanize}"
              end
            end
          end
        end

        context 'with an id that was created by a different application' do
          let!(:model) { FactoryBot.create type, uuid: uuid }
          let(:params) { { data: { type: type, id: uuid } } }

          data_requests.reject { |verb, _| verb == :post }.each do |verb, on|
            context "#{verb.upcase} ##{on}" do
              let(:verb) { verb }
              let(:on)   { on }

              it 'returns a JSON API 404 error' do
                expect { perform_request }.to  not_change { klass.count }
                                          .and not_change { model.reload.attributes }

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
          let!(:model) { FactoryBot.create type, uuid: uuid, application: application }

          context 'with a relationship' do
            context 'with no data member' do
              let(:params) do
                {
                  data: {
                    type: type,
                    id: uuid,
                    relationships: { application: { test: true } }
                  }
                }
              end

              data_requests.each do |verb, on|
                context "#{verb.upcase} ##{on}" do
                  let(:verb) { verb }
                  let(:on)   { on }

                  it 'returns a JSON API 400 error' do
                    expect { perform_request }.to  not_change { klass.count }
                                              .and not_change { model.reload.attributes }

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
                  {
                    data: {
                      type: type,
                      id: uuid,
                      relationships: { application: { data: { test: true } } }
                    }
                  }
                end

                data_requests.each do |verb, on|
                  context "#{verb.upcase} ##{on}" do
                    let(:verb) { verb }
                    let(:on)   { on }

                    it 'returns a JSON API 400 error' do
                      expect { perform_request }.to  not_change { klass.count }
                                                .and not_change { model.reload.attributes }

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
                  {
                    data: {
                      type: type,
                      id: uuid,
                      relationships: { application: { data: { type: 'resource' } } }
                    }
                  }
                end

                data_requests.each do |verb, on|
                  context "#{verb.upcase} ##{on}" do
                    let(:verb) { verb }
                    let(:on)   { on }

                    it 'returns a JSON API 409 error' do
                      expect { perform_request }.to  not_change { klass.count }
                                                .and not_change { model.reload.attributes }

                      expect(response.status).to eq 409
                      expect(error[:status]).to eq '409'
                      expect(error[:code]).to eq 'invalid_application_type'
                      expect(error[:title]).to eq 'Invalid Application Type'
                      expect(error[:detail]).to eq(
                        'The type provided for the application relationship (resource) is invalid.'
                      )
                    end
                  end
                end
              end

              context 'with a valid type' do
                context 'with no id member' do
                  let(:params) do
                    {
                      data: {
                        type: type,
                        id: uuid,
                        relationships: { application: { data: { type: 'application' } } }
                      }
                    }
                  end

                  data_requests.each do |verb, on|
                    context "#{verb.upcase} ##{on}" do
                      let(:verb) { verb }
                      let(:on)   { on }

                      it 'returns a JSON API 400 error' do
                        expect { perform_request }.to  not_change { klass.count }
                                                  .and not_change { model.reload.attributes }

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
              {
                data: {
                  type: type,
                  id: uuid,
                  relationships: {
                    application: { data: { type: 'application', id: SecureRandom.uuid } }
                  }
                }
              }
            end

            data_requests.each do |verb, on|
              context "#{verb.upcase} ##{on}" do
                let(:verb) { verb }
                let(:on)   { on }

                it 'returns a JSON API 403 error' do
                  expect { perform_request }.to  not_change { klass.count }
                                            .and not_change { model.reload.attributes }

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
