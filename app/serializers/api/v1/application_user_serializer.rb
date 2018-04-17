module Api
  module V1
    class ApplicationUserSerializer
      include FastJsonapi::ObjectSerializer
      include JsonApiSchema

      set_id :uuid

      belongs_to :application, id_method_name: :application_uuid
      required_relationships :application
    end
  end
end
