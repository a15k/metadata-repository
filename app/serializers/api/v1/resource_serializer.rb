module Api
  module V1
    class ResourceSerializer
      include FastJsonapi::ObjectSerializer
      include JsonApiSchema

      set_id :uuid

      attributes          :uri, :resource_type, :title, :content, :highlight
      required_attributes :uri, :resource_type, :content

      belongs_to :application,      id_method_name: :application_uuid
      belongs_to :application_user, id_method_name: :application_user_uuid
      belongs_to :format,           id_method_name: :format_name
      belongs_to :language,         id_method_name: :language_name
      required_relationships :application, :format
    end
  end
end
