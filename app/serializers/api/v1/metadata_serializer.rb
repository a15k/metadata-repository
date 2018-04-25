module Api
  module V1
    class MetadataSerializer
      include FastJsonapi::ObjectSerializer
      include JsonApiSchema

      set_id :uuid

      attributes          :value
      attribute_types     value: :object
      required_attributes :value

      belongs_to :application,      id_method_name: :application_uuid
      belongs_to :application_user, id_method_name: :application_user_uuid
      belongs_to :resource,         id_method_name: :resource_uuid
      belongs_to :format,           id_method_name: :format_name
      belongs_to :language,         id_method_name: :language_name
      required_relationships :application, :resource, :format
    end
  end
end
