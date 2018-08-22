require 'swagger_helper'
require_relative 'request_errors'

RSpec.describe Api::V1::StatsController, type: :request do

  before(:all) do
    @stats = FactoryBot.create :stats
    @resource = @stats.resource
    @application = @stats.application
    @other_application_stats = FactoryBot.create :stats
  end

  stats_schema_reference = { '$ref': '#/definitions/stats' }
  valid_type = described_class.valid_type
  it_behaves_like 'api v1 request errors',
                   application_proc: -> { @application },
                   base_path_template: '/resources/{resource_id}/stats',
                   schema_reference: stats_schema_reference,
                   valid_type: valid_type,
                   path_params_proc: -> do
                     parameter name: :resource_id, in: :path, type: :string,
                               description: "The associated Resource's Id",
                               schema: { type: :string, format: :uuid },
                               example: SecureRandom.uuid

                     let(:resource_id) { @resource.uuid }
                   end,
                   scope_proc: -> { @resource },
                   scope_class: 'Resource'

  no_data_setup = ->(on) do
    tags valid_type.classify
    security [ apiToken: [] ]
    schemes 'https'
    produces CONTENT_TYPE
    parameter name: :resource_id, in: :path, type: :string,
              description: "The associated Resource's Id",
              schema: { type: :string, format: :uuid },
              example: SecureRandom.uuid
    parameter name: :id, in: :path, type: :string,
              description: "The Stats object's Id",
              schema: { type: :string, format: :uuid },
              example: SecureRandom.uuid if on == :member
  end
  data_setup = ->(on) do
    instance_exec on, &no_data_setup
    consumes CONTENT_TYPE
    parameter name: :stats, in: :body, schema: stats_schema_reference
  end

  search_setup = -> do
    instance_exec :collection, &no_data_setup
    operationId 'searchStats'
    parameter name: :'filter[query]',    in: :query, type: :string, required: false,
              description: 'Query used for full text search on the Stats.' +
                           ' If not specified, no results are returned.',
              schema: { type: :string },
              example: 'physics'
    parameter name: :'filter[language]', in: :query, type: :string, required: false,
              description: 'Language used for full text search on the Stats.' +
                           ' If not specified, only exact word matches will be returned.',
              schema: { type: :string },
              example: 'english'
    parameter name: :sort, in: :query, type: :string, required: false,
              description: 'Comma-separated field names to sort Stats by.' +
                           ' Prefix with - for descending order.' +
                           ' If not specified, results are sorted by relevance instead.',
              schema: { type: :string },
              example: '-created_at,id'
  end
  create_member_setup = -> do
    instance_exec :member, &data_setup
    operationId 'createResourceStatsWithId'
  end

  let(:resource_id) { @resource.uuid }
  let(:id)          { @stats.uuid }

  after do |example|
    (example.metadata.dig(:operation, :parameters) || []).select do |parameter|
      parameter[:id] == :body
    end.each do |parameter|
      parameter[:example] = request.body.read
      request.body.rewind
    end
    example.metadata[:response][:examples] = {
      CONTENT_TYPE => JSON.parse(response.body, symbolize_names: true)
    }
  end

  context 'with valid Accept and API token headers' do
    let(:Accept)                                         { CONTENT_TYPE }
    let(Api::JsonApiController::API_TOKEN_HEADER.to_sym) { @application.token }

    path '/stats' do
      context 'with no filter param' do
        get 'List Resources created by all applications and their Stats' do
          instance_exec &search_setup

          response 200, 'success (empty result)' do
            schema stats_schema_reference

            let!(:expected_response) do
              JSON.parse(Api::V1::StatsSerializer.new(
                [], include: [ :'resource.metadatas' ]
              ).serialized_json).deep_symbolize_keys
            end

            run_test! { |response| expect(response.body_hash).to match expected_response }
          end
        end
      end

      context 'with a filter param' do
        before(:all) do
          DatabaseCleaner.start

          simple  = FactoryBot.create :language, name: 'simple'
          english = FactoryBot.create :language, name: 'english'

          all_queries = [ 'lorem', 'jumps', 'jump', 'jumping', 'jumped' ]
          [ @resource, @other_application_resource ] + 10.times.map do
            FactoryBot.create :resource, application: @application, language: simple
          end.each do |resource|
            if all_queries.any? do |query|
              resource.content.downcase.include?(query) || (
                !resource.title.nil? && resource.title.downcase.include?(query)
              )
            end
              resource.destroy
            else
              FactoryBot.create :stats, resource: resource
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
          [
            @title_resource, @content_resource, @both_resource, @fox_and_dog_resource
          ].each do |resource|
            FactoryBot.create :stats, resource: resource
          end
        end
        after(:all) do
          DatabaseCleaner.clean

          @resource.reload
        end

        context 'with no language param' do
          let(:'filter[query]') { 'lorem' }

          context 'with a sort param' do
            let(:sort) { '-created_at,id' }

            get 'List Resources created by all applications and their Stats' do
              instance_exec &search_setup

              response 200, 'success' do
                schema stats_schema_reference

                let!(:expected_response) do
                  JSON.parse(
                    Api::V1::StatsSerializer.new(
                      Stats.search(query: 'lorem', order_by: sort),
                      include: [ :'resource.metadatas' ]
                    ).serialized_json
                  ).deep_symbolize_keys
                end
                before do
                  expect(Stats).to receive(:search).with(
                    query: 'lorem', language: nil, order_by: sort
                  ).and_call_original
                end

                run_test! { |response| expect(response.body_hash).to eq expected_response }
              end
            end
          end

          context 'with no sort param' do
            get 'List Resources created by all applications and their Stats' do
              instance_exec &search_setup

              response 200, 'success' do
                schema stats_schema_reference

                let!(:expected_response) do
                  JSON.parse(
                    Api::V1::StatsSerializer.new(
                      Stats.search(query: 'lorem'), include: [ :'resource.metadatas' ]
                    ).serialized_json
                  ).deep_symbolize_keys
                end
                before do
                  expect(Stats).to receive(:search).with(
                    query: 'lorem', language: nil, order_by: nil
                  ).and_call_original
                end

                run_test! { |response| expect(response.body_hash).to eq expected_response }
              end
            end
          end
        end

        context 'with a language param' do
          let(:'filter[query]')    { 'jumps' }
          let(:'filter[language]') { 'english' }

          context 'with a sort param' do
            let(:sort) { '-created_at,id' }

            get 'List Resources created by all applications and their Stats' do
              instance_exec &search_setup

              response 200, 'success' do
                schema stats_schema_reference

                let!(:expected_response) do
                  JSON.parse(
                    Api::V1::StatsSerializer.new(
                      Stats.search(
                        query: 'jumps', language: 'english', order_by: '-created_at,id'
                      ), include: [ :'resource.metadatas' ]
                    ).serialized_json
                  ).deep_symbolize_keys
                end
                before do
                  expect(Stats).to(
                    receive(:search).with(
                      query: 'jumps', language: 'english', order_by: '-created_at,id'
                    ).and_call_original
                  )
                end

                run_test! { |response| expect(response.body_hash).to eq expected_response }
              end
            end
          end

          context 'with no sort param' do
            get 'List Resources created by all applications and their Stats' do
              instance_exec &search_setup

              response 200, 'success' do
                schema stats_schema_reference

                let!(:expected_response) do
                  JSON.parse(
                    Api::V1::StatsSerializer.new(
                      Stats.search(query: 'jumps', language: 'english'),
                      include: [ :'resource.metadatas' ]
                    ).serialized_json
                  ).deep_symbolize_keys
                end
                before do
                  expect(Stats).to receive(:search).with(
                    query: 'jumps', language: 'english', order_by: nil
                  ).and_call_original
                end

                run_test! { |response| expect(response.body_hash).to eq expected_response }
              end
            end
          end
        end
      end
    end

    path '/resources/{resource_id}/stats' do
      get 'List Stats created by all applications for the given Resource' do
        instance_exec :collection, &no_data_setup
        operationId 'getResourceStats'

        response 200, 'success' do
          schema stats_schema_reference

          run_test! do |response|
            expect(response.body_hash).to eq JSON.parse(
              Api::V1::StatsSerializer.new(
                [ @stats ], include: [ :'resource.metadatas' ]
              ).serialized_json
            ).deep_symbolize_keys
          end
        end
      end

      post 'Create a new Stats with a random Id for the given Resource' do
        instance_exec :collection, &data_setup
        operationId 'createResourceStats'

        let(:uri)   { "https://example.com/assessments/#{SecureRandom.uuid}" }
        let(:stats) do
          Api::V1::StatsSerializer.new(@stats).serializable_hash.tap do |hash|
            hash[:data].delete(:id)
          end
        end
        let(:expected_response) do
          JSON.parse(stats.to_json).deep_symbolize_keys.tap do |hash|
            hash[:data][:id] = kind_of(String)
          end
        end

        response 201, 'Stats created' do
          schema stats_schema_reference

          run_test! do |response|
            expect(response.body_hash.except(:included)).to match expected_response
          end
        end
      end
    end

    path '/resources/{resource_id}/stats/{id}' do
      get 'View the Stats with the given Id for the given Resource' do
        instance_exec :member, &no_data_setup
        operationId 'getResourceStatsWithId'

        context 'when the Stats was created by the current application' do
          response 200, 'success' do
            schema stats_schema_reference

            run_test! do |response|
              expect(response.body_hash).to eq JSON.parse(
                Api::V1::StatsSerializer.new(
                  @stats, include: [ :'resource.metadatas' ]
                ).serialized_json
              ).deep_symbolize_keys
            end
          end
        end
      end

      context 'when the Stats does not exist or was created by a different application' do
        before(:all) do
          DatabaseCleaner.start

          @application_user = @stats.application_user

          other_application = FactoryBot.create :application
          @stats.update_attribute :application, other_application
          @stats.update_attribute :application_user, nil
        end
        after(:all) do
          DatabaseCleaner.clean

          @stats.reload
        end

        let(:stats) do
          Api::V1::StatsSerializer.new(@stats).serializable_hash.tap do |hash|
            hash[:data][:relationships][:application][:data][:id] = @application.uuid
            hash[:data][:relationships][:application_user][:data] = {
              id: @application_user.uuid, type: :application_user
            }
          end
        end

        post 'Create a new Stats with the given Id for the given Resource' do
          instance_exec &create_member_setup

          response 201, 'Stats created' do
            schema stats_schema_reference

            run_test! do |response|
              expect(response.body_hash.except(:included)).to eq(
                JSON.parse(stats.to_json).deep_symbolize_keys
              )
            end
          end
        end
      end

      context 'when the Stats already exists' do
        let(:stats) do
          Api::V1::StatsSerializer.new(
            @stats, include: [ :'resource.metadatas' ]
          ).serializable_hash
        end

        post 'Create a new Stats with the given Id for the given Resource' do
          instance_exec &create_member_setup

          response 409, 'Stats uuid already exists' do
            schema FAILURE_SCHEMA

            run_test! do |response|
              expect(response.errors.first[:status]).to eq '409'
              expect(response.errors.first[:code]).to eq 'uuid_has_already_been_taken'
              expect(response.errors.first[:title]).to eq 'Stats Invalid'
              expect(response.errors.first[:detail]).to eq 'Uuid has already been taken.'
            end
          end
        end
      end

      [ :put, :patch ].each do |verb|
        public_send verb, 'Update the Stats with the given Id for the given Resource' do
          instance_exec :member, &data_setup
          operationId 'updateResourceStatsWithId'

          after(:all) { @stats.reload }

          let(:stats) do
            Api::V1::StatsSerializer.new(@other_application_stats).serializable_hash.tap do |hash|
              hash[:data][:id] = @stats.uuid
              hash[:data][:relationships][:application][:data][:id] = @application.uuid
              hash[:data][:relationships][:application_user][:data] = nil
              hash[:data][:relationships][:resource][:data][:id] = @resource.uuid
            end
          end

          context 'when the Stats was created by the current application' do
            response 200, 'Stats updated' do
              schema stats_schema_reference

              run_test! do |response|
                expect(response.body_hash.except(:included)).to eq(
                  JSON.parse(stats.to_json).deep_symbolize_keys
                )
              end
            end
          end
        end
      end

      delete 'Delete the Stats with the given Id for the given Resource' do
        instance_exec :member, &no_data_setup
        operationId 'deleteResourceStatsWithId'

        after(:all) { @stats.reload }

        context 'when the Stats was created by the current application' do
          response 200, 'Stats deleted' do
            schema stats_schema_reference

            run_test! do |response|
              expect(response.body_hash).to eq JSON.parse(
                Api::V1::StatsSerializer.new(
                  @stats, include: [ :'resource.metadatas' ]
                ).serialized_json
              ).deep_symbolize_keys
            end
          end
        end
      end
    end
  end
end
