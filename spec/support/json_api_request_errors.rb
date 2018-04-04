require 'rails_helper'

RSpec.shared_examples 'json api request errors' do |application_proc:,
                                                    base_path_template:,
                                                    json_schema_hash:,
                                                    valid_type:,
                                                    id_scope: '',
                                                    description_scope: nil,
                                                    path_params_proc: -> {}|
  class_name = valid_type.classify
  pluralized_class_name = class_name.pluralize
  description_scope ||= id_scope.blank? ? '' : "for the given #{id_scope}"

  no_data_requests = [
    [
      :get,
      :collection,
      "get#{id_scope}#{pluralized_class_name}",
      "List all #{pluralized_class_name
      } created by the current application #{description_scope}".strip
    ],
    [
      :get,
      :member,
      "get#{id_scope}#{class_name}WithId",
      "View the #{class_name} with the given Id #{description_scope}".strip
    ],
    [
      :delete,
      :member,
      "delete#{id_scope}#{class_name}WithId",
      "Delete the #{class_name} with the given Id #{description_scope}".strip
    ]
  ]
  data_requests = [
    [
      :post,
      :collection,
      "create#{id_scope}#{class_name}",
      "Create a new #{class_name} with a random Id #{description_scope}".strip
    ],
    [
      :post,
      :member,
      "create#{id_scope}#{class_name}WithId",
      "Create a new #{class_name} with the given Id #{description_scope}".strip
    ],
    [
      :put,
      :member,
      "update#{id_scope}#{class_name}WithId",
      "Update the #{class_name} with the given Id #{description_scope}".strip
    ],
    [
      :patch,
      :member,
      "update#{class_name}WithId",
      "Update the #{class_name} with the given Id #{description_scope}".strip
    ]
  ]
  requests = no_data_requests + data_requests

  let!(:application) { instance_exec &application_proc }
  let(:api_token)    { application.token }

  let(:id)           { SecureRandom.uuid }
  let(:error)        { response.errors.first }

  let(:Accept)       { CONTENT_TYPE }

  no_api_token_setup = ->(on, operation_id) do
    tags class_name
    operationId operation_id
    produces CONTENT_TYPE
    parameter name: :id, in: :path, type: :string,
              description: "The #{class_name} object's Id" if on == :member
    instance_exec &path_params_proc
  end
  no_data_setup = ->(on, operation_id) do
    instance_exec on, operation_id, &no_api_token_setup
    security [ apiToken: [] ]
  end
  data_setup = ->(on, operation_id) do
    instance_exec on, operation_id, &no_data_setup
    consumes CONTENT_TYPE
    parameter name: :params, in: :body, schema: json_schema_hash
  end

  context 'without an API token' do
    requests.each do |verb, on, operation_id, description|
      path on == :collection ? base_path_template : "#{base_path_template}/{id}" do
        public_send verb, description do
          instance_exec on, operation_id, &no_api_token_setup

          let(:verb) { verb }
          let(:on)   { on }

          response 400, 'missing api token' do
            schema json_schema_hash

            run_test! do |response|
              expect(response).to be_bad_request
              expect(error[:status]).to eq '400'
              expect(error[:code]).to eq 'missing_api_token'
              expect(error[:title]).to eq 'Missing API Token'
              expect(error[:detail]).to eq(
                "No API token was provided in the #{
                Api::JsonApiController::API_TOKEN_HEADER} header."
              )
            end
          end
        end
      end
    end
  end

  context 'with an invalid API token' do
    let(:token)                                          { SecureRandom.hex(32) }
    let(Api::JsonApiController::API_TOKEN_HEADER.to_sym) { token }

    requests.each do |verb, on, operation_id, description|
      path on == :collection ? base_path_template : "#{base_path_template}/{id}" do
        public_send verb, description do
          instance_exec on, operation_id, &no_data_setup

          let(:verb) { verb }
          let(:on)   { on }

          response 403, 'invalid api token' do
            schema json_schema_hash

            run_test! do |response|
              expect(response).to be_forbidden
              expect(error[:status]).to eq '403'
              expect(error[:code]).to eq 'invalid_api_token'
              expect(error[:title]).to eq 'Invalid API Token'
              expect(error[:detail]).to eq(
                "The API token provided in the #{
                Api::JsonApiController::API_TOKEN_HEADER} header (#{token}) is invalid."
              )
            end
          end
        end
      end
    end
  end

  context 'with a valid API token' do
    let(Api::JsonApiController::API_TOKEN_HEADER.to_sym) { api_token }

    context 'with no data member' do
      data_requests.each do |verb, on, operation_id, description|
        path on == :collection ? base_path_template : "#{base_path_template}/{id}" do
          public_send verb, description do
            instance_exec on, operation_id, &no_data_setup

            let(:verb) { verb }
            let(:on)   { on }

            response 400, 'missing data' do
              schema json_schema_hash

              run_test! do |response|
                expect(response).to be_bad_request
                expect(error[:status]).to eq '400'
                expect(error[:code]).to eq 'missing_data'
                expect(error[:title]).to eq 'Missing Data'
                expect(error[:detail]).to eq 'The data member is required by this API endpoint.'
              end
            end
          end
        end
      end
    end

    context 'with a data member' do
      context 'with no type member' do
        let(:params) { { data: { attributes: { test: true } } } }

        data_requests.each do |verb, on, operation_id, description|
          path on == :collection ? base_path_template : "#{base_path_template}/{id}" do
            public_send verb, description do
              instance_exec on, operation_id, &data_setup

              let(:verb) { verb }
              let(:on)   { on }

              response 400, 'missing type' do
                schema json_schema_hash

                run_test! do |response|
                  expect(response).to be_bad_request
                  expect(error[:status]).to eq '400'
                  expect(error[:code]).to eq 'missing_type'
                  expect(error[:title]).to eq 'Missing Type'
                  expect(error[:detail]).to eq 'The type member is required by this API endpoint.'
                end
              end
            end
          end
        end
      end

      context 'with an invalid type' do
        let(:type)   { 'object' }
        let(:params) { { data: { type: type } } }

        data_requests.each do |verb, on, operation_id, description|
          path on == :collection ? base_path_template : "#{base_path_template}/{id}" do
            public_send verb, description do
              instance_exec on, operation_id, &data_setup

              let(:verb) { verb }
              let(:on)   { on }

              response 409, 'invalid type' do
                schema json_schema_hash

                run_test! do |response|
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
        end
      end

      context 'with a valid type' do
        let(:type)   { valid_type }

        context 'with no id member' do
          let(:params) { { data: { type: type } } }

          data_requests.reject { |verb, _| verb == :post }
                       .each do |verb, on, operation_id, description|
            path on == :collection ? base_path_template : "#{base_path_template}/{id}" do
              public_send verb, description do
                instance_exec on, operation_id, &data_setup

                let(:verb) { verb }
                let(:on)   { on }

                response 400, 'missing id' do
                  schema json_schema_hash

                  run_test! do |response|
                    expect(response).to be_bad_request
                    expect(error[:status]).to eq '400'
                    expect(error[:code]).to eq 'missing_id'
                    expect(error[:title]).to eq 'Missing Id'
                    expect(error[:detail]).to eq 'The id member is required by this API endpoint.'
                  end
                end
              end
            end
          end
        end

        context 'with an id that does not match the url id' do
          let(:body_id) { SecureRandom.uuid }
          let(:params)  { { data: { type: type, id: body_id } } }

          data_requests.select { |_, on| on == :member }
                       .each do |verb, on, operation_id, description|
            path on == :collection ? base_path_template : "#{base_path_template}/{id}" do
              public_send verb, description do
                instance_exec on, operation_id, &data_setup

                let(:verb) { verb }
                let(:on)   { on }

                response 409, 'invalid id' do
                  schema json_schema_hash

                  run_test! do |response|
                    expect(response.status).to eq 409
                    expect(error[:status]).to eq '409'
                    expect(error[:code]).to eq 'invalid_id'
                    expect(error[:title]).to eq 'Invalid Id'
                    expect(error[:detail]).to eq(
                      "The id provided in the request body (#{body_id
                      }) did not match the id provided in the API endpoint URL (#{id})."
                    )
                  end
                end
              end
            end
          end
        end

        context 'with an id that does not exist' do
          let(:params) { { data: { type: type, id: id } } }

          data_requests.reject { |verb, _| verb == :post }
                       .each do |verb, on, operation_id, description|
            path on == :collection ? base_path_template : "#{base_path_template}/{id}" do
              public_send verb, description do
                instance_exec on, operation_id, &data_setup

                let(:verb) { verb }
                let(:on)   { on }

                response 404, 'not found' do
                  schema json_schema_hash

                  run_test! do |response|
                    expect(response).to be_not_found
                    expect(error[:status]).to eq '404'
                    expect(error[:code]).to eq 'not_found'
                    expect(error[:title]).to eq 'Not Found'
                    expect(error[:detail]).to eq "Couldn't find #{type.humanize}"
                  end
                end
              end
            end
          end
        end

        context 'with an id that was created by a different application' do
          let!(:model) { FactoryBot.create type, uuid: id }
          let(:params) { { data: { type: type, id: id } } }

          data_requests.reject { |verb, _| verb == :post }
                       .each do |verb, on, operation_id, description|
            path on == :collection ? base_path_template : "#{base_path_template}/{id}" do
              public_send verb, description do
                instance_exec on, operation_id, &data_setup

                let(:verb) { verb }
                let(:on)   { on }

                response 404, 'not visible' do
                  schema json_schema_hash

                  run_test! do |response|
                    expect(response).to be_not_found
                    expect(error[:status]).to eq '404'
                    expect(error[:code]).to eq 'not_found'
                    expect(error[:title]).to eq 'Not Found'
                    expect(error[:detail]).to eq "Couldn't find #{type.humanize}"
                  end
                end
              end
            end
          end
        end

        context 'with a valid id' do
          let!(:model) { FactoryBot.create type, uuid: id, application: application }

          context 'with a relationship' do
            context 'with no data member' do
              let(:params) do
                {
                  data: {
                    type: type,
                    id: id,
                    relationships: { application: { test: true } }
                  }
                }
              end

              data_requests.each do |verb, on, operation_id, description|
                path on == :collection ? base_path_template : "#{base_path_template}/{id}" do
                  public_send verb, description do
                    instance_exec on, operation_id, &data_setup

                    let(:verb) { verb }
                    let(:on)   { on }

                    response 400, 'missing relationship data' do
                      schema json_schema_hash

                      run_test! do |response|
                        expect(response).to be_bad_request
                        expect(error[:status]).to eq '400'
                        expect(error[:code]).to eq 'missing_data'
                        expect(error[:title]).to eq 'Missing Data'
                        expect(error[:detail]).to eq(
                          'The data member is required by this API endpoint.'
                        )
                      end
                    end
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
                      id: id,
                      relationships: { application: { data: { test: true } } }
                    }
                  }
                end

                data_requests.each do |verb, on, operation_id, description|
                  path on == :collection ? base_path_template : "#{base_path_template}/{id}" do
                    public_send verb, description do
                      instance_exec on, operation_id, &data_setup

                      let(:verb) { verb }
                      let(:on)   { on }

                      response 400, 'missing relationship type' do
                        schema json_schema_hash

                        run_test! do |response|
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
                end
              end

              context 'with an invalid type' do
                let(:params) do
                  {
                    data: {
                      type: type,
                      id: id,
                      relationships: { application: { data: { type: 'resource' } } }
                    }
                  }
                end

                data_requests.each do |verb, on, operation_id, description|
                  path on == :collection ? base_path_template : "#{base_path_template}/{id}" do
                    public_send verb, description do
                      instance_exec on, operation_id, &data_setup

                      let(:verb) { verb }
                      let(:on)   { on }

                      response 409, 'invalid relationship type' do
                        schema json_schema_hash

                        run_test! do |response|
                          expect(response.status).to eq 409
                          expect(error[:status]).to eq '409'
                          expect(error[:code]).to eq 'invalid_application_type'
                          expect(error[:title]).to eq 'Invalid Application Type'
                          expect(error[:detail]).to eq(
                            'The type provided for the application' +
                            ' relationship (resource) is invalid.'
                          )
                        end
                      end
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
                        id: id,
                        relationships: { application: { data: { type: 'application' } } }
                      }
                    }
                  end

                  data_requests.each do |verb, on, operation_id, description|
                    path on == :collection ? base_path_template : "#{base_path_template}/{id}" do
                      public_send verb, description do
                        instance_exec on, operation_id, &data_setup

                        let(:verb) { verb }
                        let(:on)   { on }

                        response 400, 'missing relationship id' do
                          schema json_schema_hash

                          run_test! do |response|
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
            end
          end

          context 'with an application relationship with a data member' +
                  ' with a valid type with a forbidden id' do
            let(:params) do
              {
                data: {
                  type: type,
                  id: id,
                  relationships: {
                    application: { data: { type: 'application', id: SecureRandom.uuid } }
                  }
                }
              }
            end

            data_requests.each do |verb, on, operation_id, description|
              path on == :collection ? base_path_template : "#{base_path_template}/{id}" do
                public_send verb, description do
                  instance_exec on, operation_id, &data_setup

                  let(:verb) { verb }
                  let(:on)   { on }

                  response 403, 'forbidden application id' do
                    schema json_schema_hash

                    run_test! do |response|
                      expect(response).to be_forbidden
                      expect(error[:status]).to eq '403'
                      expect(error[:code]).to eq 'forbidden_application_id'
                      expect(error[:title]).to eq 'Forbidden Application Id'
                      expect(error[:detail]).to eq(
                        "You are only allowed to provide your own application id (#{
                        application.uuid})."
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
  end
end
