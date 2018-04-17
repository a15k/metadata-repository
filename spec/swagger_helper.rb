require 'rails_helper'
require 'requests/test_response'

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's confiugred to server Swagger from the same folder
  config.swagger_root = Rails.root.join 'swagger'

  # Define one or more Swagger documents and provide global metadata for each one
  # When you run the 'rswag:specs:to_swagger' rake task, the complete Swagger will
  # be generated at the provided relative path under swagger_root
  # By default, the operations defined in spec files are added to the first
  # document below. You can override this behavior by adding a swagger_doc tag to the
  # the root example_group in your specs, e.g. describe '...', swagger_doc: 'v2/swagger.json'
  config.swagger_docs = {
    'v1/swagger.json' => {
      swagger: '2.0',
      info: {
        title: 'Assessment Network Metadata API V1',
        version: 'v1'
      },
      basePath: '/api',
      securityDefinitions: {
        apiToken: {
          type: :apiKey,
          name: Api::JsonApiController::API_TOKEN_HEADER,
          in: :header
        }
      },
      definitions: {
        application_user: { '$ref': 'public/schemas/api/v1/application_user.schema.json' },
        resource:         { '$ref': 'public/schemas/api/v1/resource.schema.json'         },
        metadata:         { '$ref': 'public/schemas/api/v1/metadata.schema.json'         },
        stats:            { '$ref': 'public/schemas/api/v1/stats.schema.json'            },
        failure:          { '$ref': 'public/schemas/failure.schema.json'                 }
      }
    }
  }
end
