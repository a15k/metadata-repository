namespace :swagger do
  desc 'Convert swagger.json from Swagger 2.0 to OpenAPI 3.0'
  task :convert do
    Dir[Rails.root.join 'swagger/**/swagger.json'].each do |swagger_path|
      `yarn run swagger2openapi #{swagger_path} -o #{swagger_path}`

      swagger = JSON.parse File.read swagger_path

      swagger['components']['schemas'].each_value do |definition|
        next definition unless definition.has_key? '$ref'

        definition['$ref'].sub! 'public/', '../../'
      end

      # Fix for swagger-ui bug: expects examples in the wrong place according to OAS 3.0
      swagger['paths'].each_value do |path|
        path.each_value do |operation|
          operation['responses'].each_value do |response|
            content = response['content']
            content.each do |key, value|
              next unless value.has_key? 'examples'

              response['examples'] = value.delete('examples').transform_values! do |example|
                example['value']
              end

              content.delete(key) if value.empty?
            end
          end
        end
      end

      File.write swagger_path, JSON.pretty_generate(swagger)
    end
  end

  desc 'Generate swagger.json from scratch'
  task generate: [ :'serializers:dump_schemas', :'rswag:specs:swaggerize', :convert ]
end
