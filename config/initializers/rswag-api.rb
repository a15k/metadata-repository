Rswag::Api.configure do |c|
  # Specify a root folder where Swagger JSON files are located
  # This is used by the Swagger middleware to serve requests for API descriptions
  # NOTE: If you're using rswag-specs to generate Swagger, you'll need to ensure
  # that it's configured to generate files in the same folder
  c.swagger_root = Rails.root.join 'swagger'

  # Inject a lamda function to alter the returned Swagger prior to serialization
  # The function will have access to the rack env for the current request
  # For example, you could leverage this to dynamically assign the "host" property
  c.swagger_filter = ->(swagger, env) do
    request = Rack::Request.new(env)

    swagger['servers'] = [
      {
        url: request.host_with_port,
        description: 'The metadata repository server'
      }
    ]
  end
end
