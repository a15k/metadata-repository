module Api
  module V1
    class ResourceSerializer
      include FastJsonapi::ObjectSerializer
      include JsonApiSchema

      set_id :uuid

      attributes          :uri, :resource_type, :title, :content, :headline
      required_attributes :uri, :resource_type, :content

      has_many :metadatas, id_method_name: :metadata_uuids, object_method_name: :scoped_metadatas
      has_many :stats,     id_method_name: :stats_uuids,    object_method_name: :scoped_stats

      belongs_to :application,      id_method_name: :application_uuid
      belongs_to :application_user, id_method_name: :application_user_uuid
      belongs_to :format,           id_method_name: :format_name
      belongs_to :language,         id_method_name: :language_name

      required_relationships :application, :format
    end
  end
end
