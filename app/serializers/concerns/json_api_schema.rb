module JsonApiSchema
  extend ActiveSupport::Concern

  class_methods do
    def json_schema_hash(create: false)
      class_name = name.demodulize.chomp('Serializer')
      attributes = (attributes_to_serialize || {}).keys
      relationships = (relationships_to_serialize || {}).keys

      # Load the generic json-api schema
      json_api_schema_filepath = Rails.root.join 'vendor', 'schemas', 'json-api.schema.json'
      json_api_schema_file = File.open json_api_schema_filepath
      json_api_schema = JSON.parse json_api_schema_file

      # Customize the schema for the current model
      # JSON Schema Draft 6 is required for propertyNames
      json_api_schema['$schema'] = 'http://json-schema.org/draft-06/schema#'
      json_api_schema['title'] = "#{class_name} JSON API Schema"
      json_api_schema['description'] = "JSON API schema for #{class_name} objects."
      json_api_schema['definitions']['resource']['required'] = [ 'type' ] if create
      json_api_schema['definitions']['attributes']['propertyNames'] = { 'enum' => attributes }
      json_api_schema['definitions']['relationships']['propertyNames'] = { 'enum' => relationships }

      json_api_schema
    end

    def json_schema(create: false)
      json_schema_hash(create: create).to_json
    end
  end
end
