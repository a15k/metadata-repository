module Api
  class JsonApiController < ActionController::API
    respond_to CONTENT_TYPE

    API_TOKEN_HEADER = 'Metadata-Api-Token'

    before_action :require_api_token!, :validate_api_token!
    before_action :validate_type!, :validate_id!, only: [ :show, :create, :update, :destroy ]

    rescue_from ActionController::ParameterMissing, with: :render_parameter_missing_error
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found_error

    def self.valid_type
      name.split('::').last.chomp('Controller').underscore.singularize
    end

    protected

    def render_not_found_error
      render status: :not_found, content_type: CONTENT_TYPE, json: {
        errors: [
          {
            status: '404',
            code: 'not_found',
            title: 'Not Found',
            detail: 'An object matching the type and id provided could not be found.'
          }
        ]
      }
    end

    def render_parameter_missing_error(exception)
      param = exception.param

      render status: :bad_request, content_type: CONTENT_TYPE, json: {
        errors: [
          {
            status: '400',
            code: "missing_#{param}",
            title: "Missing #{param.to_s.humanize}",
            detail: "The #{param} member is required by this API endpoint."
          }
        ]
      }
    end

    def api_token
      request.headers[API_TOKEN_HEADER]
    end

    def current_application
      Application.find_by(token: api_token)
    end

    def uuid_param
      params[:uuid]
    end

    def id_param
      params.require(:data).require(:id)
    end

    def type_param
      params.require(:data).require(:type)
    end

    def attributes
      params.require(:attributes)
    end

    def valid_id?
      id_param == uuid_param
    end

    def valid_type?
      type_param == self.class.valid_type
    end

    def require_api_token!
      render status: :bad_request, content_type: CONTENT_TYPE, json: {
        errors: [
          {
            status: '400',
            code: 'missing_api_token',
            title: 'Missing API Token',
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
            title: 'Invalid API Token',
            detail: "The API token provided in the #{API_TOKEN_HEADER} header is invalid."
          }
        ]
      } if current_application.nil?
    end

    def validate_id!
      render status: :conflict, content_type: CONTENT_TYPE, json: {
        errors: [
          {
            status: '409',
            code: 'invalid_id',
            title: 'Invalid Id',
            detail: 'The id provided did not match the API endpoint URL.'
          }
        ]
      } unless valid_id?
    end

    def validate_type!
      render status: :conflict, content_type: CONTENT_TYPE, json: {
        errors: [
          {
            status: '409',
            code: 'invalid_type',
            title: 'Invalid Type',
            detail: 'The type provided is not supported by this API endpoint.'
          }
        ]
      } unless valid_type?
    end

    def json_api_attributes
      data = params.require :data
      data.require :type
      data.require :id

      data.require :attributes
    end
  end
end
