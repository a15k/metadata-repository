module Api
  module V1
    class ApplicationSerializer
      include FastJsonapi::ObjectSerializer
      include JsonApiSchema

      set_id :uuid

      attributes          :name
      required_attributes :name
    end
  end
end
