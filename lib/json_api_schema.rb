module JsonApiSchema
  extend ActiveSupport::Concern

  class_methods do
    def json_schema(create: false)
      humanized_name = name.demodulize.chomp('Serializer').underscore.humanize
      json_api_schema_filename = create ? 'json_api_create' : 'json-api'
      json_api_schema_filepath = File.join(
        Rails.root, 'public', "#{json_api_schema_filename}.schema.json"
      )
      json_api_schema_file = File.open json_api_schema_filepath
      json_api_schema = JSON.parse json_api_schema_file

      {
        "$schema": "http://json-schema.org/draft-06/schema#",
        title: "#{humanized_name} JSON API Schema",
        description: "JSON API schema for #{humanized_name} objects.",
        allOf: [
          json_api_schema,
          {
            definitions: {
              resource:      { properties:    { id: { format: :uuid } } },
              attributes:    { propertyNames: { enum: attributes_to_serialize.keys } },
              relationships: { propertyNames: { enum: relationships_to_serialize.keys } }
            }
          }
        ]
      }.to_json
    end
  end
end
