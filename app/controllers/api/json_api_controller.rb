module Api
  class JsonApiController < ActionController::API
    respond_to CONTENT_TYPE

    API_TOKEN_HEADER = 'Metadata-Api-Token'

    before_action :require_api_token!, :validate_api_token!
    before_action :validate_type!, :validate_id!, :validate_relationships!,
                  only: [ :create, :update ]

    rescue_from ActionController::ParameterMissing, with: :render_parameter_missing_error
    rescue_from ActiveRecord::RecordNotFound,       with: :render_not_found_error
    rescue_from ActiveRecord::RecordInvalid,        with: :render_validation_errors

    def self.valid_type
      name.demodulize.chomp('Controller').underscore.singularize
    end

    protected

    def render_parameter_missing_error(exception)
      param = exception.param

      render status: :bad_request, content_type: CONTENT_TYPE, json: {
        errors: [
          {
            status: '400',
            code: "missing_#{param}",
            title: "Missing #{param}",
            detail: "The \"#{param}\" member is required by this API endpoint."
          }
        ]
      }
    end

    def render_not_found_error(exception)
      render status: :not_found, content_type: CONTENT_TYPE, json: {
        errors: [
          {
            status: '404',
            code: 'not_found',
            title: 'Not Found',
            detail: exception.message
          }
        ]
      }
    end

    def render_validation_errors(exception)
      title = "#{exception.record.class.name.classify} Invalid"
      statuses = exception.record.errors.details.map do |attribute, errors|
        errors.any? { |error| error[:error] == :taken } ? '409' : '422'
      end
      status = statuses.any? { |status| status == '409' } ? :conflict : :unprocessable_entity

      render status: status, content_type: CONTENT_TYPE, json: {
        errors: exception.record.errors.full_messages.each_with_index.map do |message, index|
          {
            status: statuses[index],
            code: message.downcase.gsub(/[^a-z0-9-]+/, '_'),
            title: title,
            detail: "#{message}."
          }
        end
      }
    end

    def api_token
      request.headers[API_TOKEN_HEADER]
    end

    def current_application
      Application.find_by(token: api_token)
    end

    def path_id_param
      params[:uuid]
    end

    def body_id_param
      data = params.require(:data)
      action_name == 'create' ? data.permit(:id)[:id] : data.require(:id)
    end

    def type_param
      params.require(:data).require(:type)
    end

    def attributes
      params.require(:attributes)
    end

    def require_api_token!
      render status: :bad_request, content_type: CONTENT_TYPE, json: {
        errors: [
          {
            status: '400',
            code: 'missing_api_token',
            title: 'Missing api token',
            detail: "No API token was provided in the #{API_TOKEN_HEADER} header."
          }
        ]
      } if api_token.nil?
    end

    def validate_api_token!
      render status: :forbidden, content_type: CONTENT_TYPE, json: {
        errors: [
          {
            status: '403',
            code: 'invalid_api_token',
            title: 'Invalid api token',
            detail: "The API token provided in the #{API_TOKEN_HEADER
                    } header (#{api_token}) is invalid."
          }
        ]
      } if current_application.nil?
    end

    def validate_type!
      render status: :conflict, content_type: CONTENT_TYPE, json: {
        errors: [
          {
            status: '409',
            code: 'invalid_type',
            title: 'Invalid type',
            detail: "The type provided (#{type_param
                    }) is not the one supported by this API endpoint (#{self.class.valid_type})."
          }
        ]
      } unless type_param == self.class.valid_type
    end

    def validate_id!
      render status: :conflict, content_type: CONTENT_TYPE, json: {
        errors: [
          {
            status: '409',
            code: 'invalid_id',
            title: 'Invalid id',
            detail: "The id provided in the request body (#{body_id_param
                    }) did not match the id provided in the API endpoint URL (#{path_id_param})."
          }
        ]
      } unless path_id_param.nil? || body_id_param == path_id_param
    end

    def validate_relationships!
      return if json_api_data[:relationships].nil?

      json_api_data[:relationships].each do |rel, val|
        next if val.nil? || val.has_key?(:data) && val[:data].nil?

        data = val.require(:data)

        type = data.require(:type)
        render(status: :conflict, content_type: CONTENT_TYPE, json: {
          errors: [
            {
              status: '409',
              code: "invalid_#{rel}_type",
              title: "Invalid #{rel} type",
              detail: "The type provided for the #{rel} relationship (#{type}) is invalid."
            }
          ]
        }) && return unless type == rel

        id = data.require :id
        render(status: :forbidden, content_type: CONTENT_TYPE, json: {
          errors: [
            {
              status: '403',
              code: 'forbidden_application_id',
              title: "Forbidden application id",
              detail: "You are only allowed to provide your own application id (#{
                      current_application.uuid})."
            }
          ]
        }) && return if rel == 'application' && id != current_application.uuid
      end
    end

    def json_api_data
      params.require(:data).tap do |data|
        data.require :type
        data.require(:id) unless action_name == 'create'
      end
    end

    def json_api_attributes(required: true)
      data = json_api_data

      attributes = required ? data.require(:attributes) :
                              data.permit(:attributes).fetch(:attributes, {})
      attributes[:uuid] = data.fetch(:id) { SecureRandom.uuid }
      attributes
    end

    def json_api_relationships
      ActionController::Parameters.new(
        {}.tap do |relationships|
          json_api_data.require(:relationships).each do |rel, val|
            relationships["#{rel}_id".to_sym] = val.nil? ? nil : val.dig(:data, :id)
          end
        end
      )
    end
  end
end
