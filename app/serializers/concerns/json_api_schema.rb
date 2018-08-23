module JsonApiSchema
  extend ActiveSupport::Concern

  # These differ from JSON-API in that the linkage is inside the data field
  REQUIRED_RELATIONSHIP_TO_ONE_SCHEMA = {
    type: :object,
    properties: {
      links: {
        '$ref': '#/definitions/relationshipLinks'
      },
      data: {
        description: 'Member, whose value represents "resource linkage".',
        '$ref': '#/definitions/linkage'
      },
      meta: {
        '$ref': '#/definitions/meta'
      }
    },
    required: [ :data ],
    additionalProperties: false
  }

  OPTIONAL_RELATIONSHIP_TO_ONE_SCHEMA = {
    type: :object,
    properties: {
      links: {
        '$ref': '#/definitions/relationshipLinks'
      },
      data: {
        description: 'Member, whose value represents "resource linkage".',
        '$ref': '#/definitions/relationshipToOne'
      },
      meta: {
        '$ref': '#/definitions/meta'
      }
    },
    required: [ :data ],
    additionalProperties: false
  }

  RELATIONSHIP_TO_MANY_SCHEMA = {
    type: :object,
    properties: {
      links: {
        '$ref': '#/definitions/relationshipLinks'
      },
      data: {
        description: 'Member, whose value represents "resource linkage".',
        '$ref': '#/definitions/relationshipToMany'
      },
      meta: {
        '$ref': '#/definitions/meta'
      }
    },
    required: [ :data ],
    additionalProperties: false
  }

  class_methods do
    def attribute_types(**attribute_types)
      @attribute_types = attribute_types
    end

    def required_attributes(*required_attributes)
      @required_attributes = required_attributes
    end

    def required_relationships(*required_relationships)
      @required_relationships = required_relationships
    end

    def json_schema_hash(create: false)
      class_name = name.demodulize.chomp('Serializer')
      attributes = (attributes_to_serialize || {}).keys
      to_many_relationships, to_one_relationships = (relationships_to_serialize || [])
                                                      .partition do |key, value|
        value.relationship_type == :has_many
      end

      # Load the generic json-api success schema
      json_api_schema_filepath = Rails.root.join 'app', 'schemas', 'success.schema.json'
      json_api_schema_file = File.open json_api_schema_filepath
      json_api_schema = JSON.parse(json_api_schema_file).deep_symbolize_keys

      # Customize the schema for the current model
      json_api_schema[:title] = "#{class_name} JSON API Schema"
      json_api_schema[:description] = "JSON API schema for #{class_name} objects."

      json_api_schema[:definitions][:includedAttributes] =
        json_api_schema[:definitions][:attributes].deep_dup
      json_api_schema[:definitions][:includedRelationships] =
        json_api_schema[:definitions][:relationships].deep_dup
      json_api_schema[:definitions][:includedResource] =
        json_api_schema[:definitions][:resource].deep_dup
      json_api_schema[:definitions][:includedResource][:properties][:attributes][:$ref] =
        '#/definitions/includedAttributes'
      json_api_schema[:definitions][:includedResource][:properties][:relationships][:$ref] =
        '#/definitions/includedRelationships'
      json_api_schema[:properties][:included][:items][:$ref] = '#/definitions/includedResource'

      json_api_schema[:definitions][:resource][:required] = [ :type ] if create
      json_api_schema[:definitions][:resource][:required] << :attributes \
        unless @required_attributes.blank?
      json_api_schema[:definitions][:resource][:required] << :relationships \
        unless @required_relationships.blank?

      json_api_schema[:definitions][:attributes][:properties] = {}
      attributes.each do |attribute|
        attribute_sym = attribute.to_sym
        type = (@attribute_types || {}).fetch(attribute_sym, :string).to_sym

        json_api_schema[:definitions][:attributes][:properties][attribute_sym] =
          type == :null || (@required_attributes || []).include?(attribute_sym) ?
            { type: type } : { oneOf: [ { type: type }, { type: :null } ] }
      end
      json_api_schema[:definitions][:attributes][:required] = @required_attributes \
        unless @required_attributes.blank?
      json_api_schema[:definitions][:attributes].delete :patternProperties

      json_api_schema[:definitions][:data][:oneOf].delete_at -1

      json_api_schema[:definitions][:relationships][:properties] = {}
      to_many_relationships.each do |to_many_relationship, _|
        to_many_relationship_sym = to_many_relationship.to_sym

        json_api_schema[:definitions][:relationships][:properties][to_many_relationship_sym] =
          RELATIONSHIP_TO_MANY_SCHEMA
      end
      to_one_relationships.each do |to_one_relationship, _|
        to_one_relationship_sym = to_one_relationship.to_sym

        json_api_schema[:definitions][:relationships][:properties][to_one_relationship_sym] =
          (@required_relationships || []).include?(to_one_relationship_sym) ?
            REQUIRED_RELATIONSHIP_TO_ONE_SCHEMA : OPTIONAL_RELATIONSHIP_TO_ONE_SCHEMA
      end
      json_api_schema[:definitions][:relationships][:required] = @required_relationships \
        unless @required_relationships.blank?
      json_api_schema[:definitions][:relationships].delete :patternProperties

      json_api_schema
    end

    def json_schema(create: false)
      json_schema_hash(create: create).to_json
    end
  end
end
