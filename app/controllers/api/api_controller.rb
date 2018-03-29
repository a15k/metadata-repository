module Api
  class ApiController < ActionController::API
    respond_to CONTENT_TYPE

    API_TOKEN_HEADER = 'Metadata-Api-Token'

    before_action :validate_api_token!
    before_action :validate_type!, except: :index
    before_action :validate_uuid!, except: [ :index, :create ]

    protected

    def self.valid_type
      name.split('::').last.chomp('Controller').underscore.singularize
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
      params.dig(:data, :id)
    end

    def type_param
      params.dig(:data, :type)
    end

    def valid_id?
      id_param == uuid_param
    end

    def valid_type?
      type_param == valid_type
    end

    def require_api_token!
      render status: :forbidden, content_type: CONTENT_TYPE, json: {
        errors: [
          {
            status: '403',
            code: 'missing_api_token',
            title: 'Missing API Token',
            detail: "No API token was provided in the #{API_TOKEN_HEADER} header."
          }
        ]
      } if api_token.nil?
    end

    def validate_api_token!
      require_api_token!

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

    def require_id!
      render status: :conflict, content_type: CONTENT_TYPE, json: {
        errors: [
          {
            status: '409',
            code: 'missing_id',
            title: 'Missing ID',
            detail: "The id member is required by all non-CREATE API endpoints."
          }
        ]
      } if id_param.nil?
    end

    def validate_id!
      require_id!

      render status: :conflict, content_type: CONTENT_TYPE, json: {
        errors: [
          {
            status: '409',
            code: 'invalid_id',
            title: 'Invalid ID',
            detail: "The id member provided did not match the API endpoint URL."
          }
        ]
      } unless valid_id?
    end

    def require_type!
      render status: :conflict, content_type: CONTENT_TYPE, json: {
        errors: [
          {
            status: '409',
            code: 'missing_type',
            title: 'Missing Type',
            detail: "The type member is required by all API endpoints."
          }
        ]
      } if type_param.nil?
    end

    def validate_type!
      require_type!

      render status: :conflict, content_type: CONTENT_TYPE, json: {
        errors: [
          {
            status: '409',
            code: 'invalid_type',
            title: 'Invalid Type',
            detail: "The type member provided is not supported by this API endpoint."
          }
        ]
      } unless valid_type?
    end
  end
end
