module Api
  module V1
    class ResourceSerializer
      include FastJsonapi::ObjectSerializer

      set_id :uuid

      attributes :uuid, :uri, :resource_type, :title, :content

      belongs_to :application,      id_method_name: :application_uuid
      belongs_to :application_user, id_method_name: :application_user_uuid
      belongs_to :format,           id_method_name: :format_name
      belongs_to :language,         id_method_name: :language_name
    end
  end
end
