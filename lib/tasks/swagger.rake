namespace :swagger do
  desc 'Convert swagger.json from Swagger 2.0 to OpenAPI 3.0'
  task :convert do
    Dir[Rails.root.join 'swagger/**/swagger.json'].each do |swagger_path|
      `yarn run swagger2openapi #{swagger_path} -o #{swagger_path}`
    end
  end

  desc 'Generate swagger.json from scratch'
  task generate: [ :'serializers:dump_schemas', :'rswag:specs:swaggerize', :convert ]
end
