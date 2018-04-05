namespace :serializers do
  desc 'Dump all app/serializer/api JSON schemas to public/schemas/api'
  task dump_schemas: :environment do
    Dir[Rails.root.join 'app/serializers/api/**/*.rb'].each do |src_path|
      serializer_path = src_path.split('app/serializers').last
      serializer_dir = File.dirname serializer_path
      filename = File.basename serializer_path, '_serializer.rb'
      relative_dest_dir = File.join 'public', 'schemas', serializer_dir
      relative_dest_path = File.join relative_dest_dir, "#{filename}.schema.json"
      klass = serializer_path.chomp('.rb').classify.constantize

      FileUtils.mkdir_p relative_dest_dir
      File.write relative_dest_path, klass.json_schema
    end
  end
end
