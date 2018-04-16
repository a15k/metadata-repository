require 'swagger_helper'

RSpec.shared_examples 'api v1 request errors' do |application_proc:,
                                                  base_path_template:,
                                                  schema_reference:,
                                                  valid_type:,
                                                  description_scope: nil,
                                                  path_params_proc: -> {},
                                                  scope_proc: -> {},
                                                  scope_class: nil,
                                                  fully_scoped: false|
  class_name = valid_type.classify
  pluralized_class_name = class_name.pluralize
  description_scope_class ||= scope_class.blank? ? '' : "for the given #{scope_class}"

  no_data_requests = [
    [
      :get,
      :collection,
      "get#{scope_class}#{pluralized_class_name}",
      "List #{pluralized_class_name} created by all applications #{description_scope_class}".strip
    ],
    [
      :get,
      :member,
      "get#{scope_class}#{class_name}WithId",
      "View the #{class_name} with the given Id #{description_scope_class}".strip
    ],
    [
      :delete,
      :member,
      "delete#{scope_class}#{class_name}WithId",
      "Delete the #{class_name} with the given Id #{description_scope_class}".strip
    ]
  ]
  data_requests = [
    [
      :post,
      :collection,
      "create#{scope_class}#{class_name}",
      "Create a new #{class_name} with a random Id #{description_scope_class}".strip
    ],
    [
      :post,
      :member,
      "create#{scope_class}#{class_name}WithId",
      "Create a new #{class_name} with the given Id #{description_scope_class}".strip
    ],
    [
      :put,
      :member,
      "update#{scope_class}#{class_name}WithId",
      "Update the #{class_name} with the given Id #{description_scope_class}".strip
    ],
    [
      :patch,
      :member,
      "update#{class_name}WithId",
      "Update the #{class_name} with the given Id #{description_scope_class}".strip
    ]
  ]
  requests = no_data_requests + data_requests

  param_name = valid_type.to_sym

  let!(:application) { instance_exec &application_proc }
  let!(:scope)       { instance_exec &scope_proc }

  let(:api_token)    { application.token }
  let(:scope_hash)   { scope.nil? ? {} : { scope.class.name.underscore.to_sym => scope } }

  let(:id)           { SecureRandom.uuid }

  let(:Accept)       { CONTENT_TYPE }

  after do |example|
    example.metadata[:response][:examples] = {
      'application/json' => JSON.parse(response.body, symbolize_names: true)
    }
  end

  no_api_token_setup = ->(on, operation_id) do
    tags class_name
    operationId operation_id
    schemes 'https'
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
    parameter name: param_name, in: :body, schema: schema_reference
  end

  context 'without an API token' do
    requests.each do |verb, on, operation_id, description|
      path on == :collection ? base_path_template : "#{base_path_template}/{id}" do
        public_send verb, description do
          instance_exec on, operation_id, &no_api_token_setup

          let(:verb) { verb }
          let(:on)   { on }

          response 400, 'missing api token' do
            schema schema_reference

            run_test! do |response|
              expect(response.errors.first[:status]).to eq '400'
              expect(response.errors.first[:code]).to eq 'missing_api_token'
              expect(response.errors.first[:title]).to eq 'Missing api token'
              expect(response.errors.first[:detail]).to eq(
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
            schema schema_reference

            run_test! do |response|
              expect(response.errors.first[:status]).to eq '403'
              expect(response.errors.first[:code]).to eq 'invalid_api_token'
              expect(response.errors.first[:title]).to eq 'Invalid api token'
              expect(response.errors.first[:detail]).to eq(
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
              schema schema_reference

              run_test! do |response|
                expect(response.errors.first[:status]).to eq '400'
                expect(response.errors.first[:code]).to eq 'missing_data'
                expect(response.errors.first[:title]).to eq 'Missing data'
                expect(response.errors.first[:detail]).to eq(
                  'The "data" member is required by this API endpoint.'
                )
              end
            end
          end
        end
      end
    end

    context 'with a data member' do
      context 'with no type member' do
        let(param_name) { { data: { attributes: { test: true } } } }

        data_requests.each do |verb, on, operation_id, description|
          path on == :collection ? base_path_template : "#{base_path_template}/{id}" do
            public_send verb, description do
              instance_exec on, operation_id, &data_setup

              let(:verb) { verb }
              let(:on)   { on }

              response 400, 'missing type' do
                schema schema_reference

                run_test! do |response|
                  expect(response.errors.first[:status]).to eq '400'
                  expect(response.errors.first[:code]).to eq 'missing_type'
                  expect(response.errors.first[:title]).to eq 'Missing type'
                  expect(response.errors.first[:detail]).to eq(
                    'The "type" member is required by this API endpoint.'
                  )
                end
              end
            end
          end
        end
      end

      context 'with an invalid type' do
        let(:type)      { 'object' }
        let(param_name) { { data: { type: type } } }

        data_requests.each do |verb, on, operation_id, description|
          path on == :collection ? base_path_template : "#{base_path_template}/{id}" do
            public_send verb, description do
              instance_exec on, operation_id, &data_setup

              let(:verb) { verb }
              let(:on)   { on }

              response 409, 'invalid type' do
                schema schema_reference

                run_test! do |response|
                  expect(response.errors.first[:status]).to eq '409'
                  expect(response.errors.first[:code]).to eq 'invalid_type'
                  expect(response.errors.first[:title]).to eq 'Invalid type'
                  expect(response.errors.first[:detail]).to eq(
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
          let(param_name) { { data: { type: type } } }

          data_requests.reject { |verb, _| verb == :post }
                       .each do |verb, on, operation_id, description|
            path on == :collection ? base_path_template : "#{base_path_template}/{id}" do
              public_send verb, description do
                instance_exec on, operation_id, &data_setup

                let(:verb) { verb }
                let(:on)   { on }

                response 400, 'missing id' do
                  schema schema_reference

                  run_test! do |response|
                    expect(response.errors.first[:status]).to eq '400'
                    expect(response.errors.first[:code]).to eq 'missing_id'
                    expect(response.errors.first[:title]).to eq 'Missing id'
                    expect(response.errors.first[:detail]).to eq(
                      'The "id" member is required by this API endpoint.'
                    )
                  end
                end
              end
            end
          end
        end

        context 'with an id that does not match the url id' do
          let(:body_id)    { SecureRandom.uuid }
          let(param_name)  { { data: { type: type, id: body_id } } }

          data_requests.select { |_, on| on == :member }
                       .each do |verb, on, operation_id, description|
            path on == :collection ? base_path_template : "#{base_path_template}/{id}" do
              public_send verb, description do
                instance_exec on, operation_id, &data_setup

                let(:verb) { verb }
                let(:on)   { on }

                response 409, 'invalid id' do
                  schema schema_reference

                  run_test! do |response|
                    expect(response.errors.first[:status]).to eq '409'
                    expect(response.errors.first[:code]).to eq 'invalid_id'
                    expect(response.errors.first[:title]).to eq 'Invalid id'
                    expect(response.errors.first[:detail]).to eq(
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
          let(param_name) { { data: { type: type, id: id } } }

          data_requests.reject { |verb, _| verb == :post }
                       .each do |verb, on, operation_id, description|
            path on == :collection ? base_path_template : "#{base_path_template}/{id}" do
              public_send verb, description do
                instance_exec on, operation_id, &data_setup

                let(:verb) { verb }
                let(:on)   { on }

                response 404, 'not found' do
                  schema schema_reference

                  run_test! do |response|
                    expect(response.errors.first[:status]).to eq '404'
                    expect(response.errors.first[:code]).to eq 'not_found'
                    expect(response.errors.first[:title]).to eq 'Not Found'
                    expect(response.errors.first[:detail]).to eq "Couldn't find #{type.classify}"
                  end
                end
              end
            end
          end
        end

        context 'with an id that was created by a different application' do
          let!(:model)    { FactoryBot.create type, scope_hash.merge(uuid: id) }
          let(param_name) { { data: { type: type, id: id } } }

          data_requests.reject { |verb, _| verb == :post }
                       .each do |verb, on, operation_id, description|
            path on == :collection ? base_path_template : "#{base_path_template}/{id}" do
              public_send verb, description do
                instance_exec on, operation_id, &data_setup

                let(:verb) { verb }
                let(:on)   { on }

                if fully_scoped
                  response 404, 'not visible' do
                    schema schema_reference

                    run_test! do |response|
                      expect(response.errors.first[:status]).to eq '404'
                      expect(response.errors.first[:code]).to eq 'not_found'
                      expect(response.errors.first[:title]).to eq 'Not Found'
                      expect(response.errors.first[:detail]).to eq "Couldn't find #{type.classify}"
                    end
                  end
                else
                  response 403, 'forbidden' do
                    schema schema_reference

                    run_test! do |response|
                      expect(response.errors.first[:status]).to eq '403'
                      expect(response.errors.first[:code]).to eq 'forbidden'
                      expect(response.errors.first[:title]).to eq 'Forbidden'
                      expect(response.errors.first[:detail]).to eq(
                        "You are not allowed to modify the given #{type.classify}."
                      )
                    end
                  end
                end
              end
            end
          end
        end

        context 'with a valid id' do
          let!(:model) do
            FactoryBot.create type, scope_hash.merge(uuid: id, application: application)
          end

          context 'with a relationship' do
            context 'with no data member' do
              let(param_name) do
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
                      schema schema_reference

                      run_test! do |response|
                        expect(response.errors.first[:status]).to eq '400'
                        expect(response.errors.first[:code]).to eq 'missing_data'
                        expect(response.errors.first[:title]).to eq 'Missing data'
                        expect(response.errors.first[:detail]).to eq(
                          'The "data" member is required by this API endpoint.'
                        )
                      end
                    end
                  end
                end
              end
            end

            context 'with a data member' do
              context 'with no type member' do
                let(param_name) do
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
                        schema schema_reference

                        run_test! do |response|
                          expect(response.errors.first[:status]).to eq '400'
                          expect(response.errors.first[:code]).to eq 'missing_type'
                          expect(response.errors.first[:title]).to eq 'Missing type'
                          expect(response.errors.first[:detail]).to eq(
                            'The "type" member is required by this API endpoint.'
                          )
                        end
                      end
                    end
                  end
                end
              end

              context 'with an invalid type' do
                let(param_name) do
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
                        schema schema_reference

                        run_test! do |response|
                          expect(response.errors.first[:status]).to eq '409'
                          expect(response.errors.first[:code]).to eq 'invalid_application_type'
                          expect(response.errors.first[:title]).to eq 'Invalid application type'
                          expect(response.errors.first[:detail]).to eq(
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
                  let(param_name) do
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
                          schema schema_reference

                          run_test! do |response|
                            expect(response.errors.first[:status]).to eq '400'
                            expect(response.errors.first[:code]).to eq 'missing_id'
                            expect(response.errors.first[:title]).to eq 'Missing id'
                            expect(response.errors.first[:detail]).to eq(
                              'The "id" member is required by this API endpoint.'
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
            let(param_name) do
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
                    schema schema_reference

                    run_test! do |response|
                      expect(response.errors.first[:status]).to eq '403'
                      expect(response.errors.first[:code]).to eq 'forbidden_application_id'
                      expect(response.errors.first[:title]).to eq 'Forbidden application id'
                      expect(response.errors.first[:detail]).to eq(
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
