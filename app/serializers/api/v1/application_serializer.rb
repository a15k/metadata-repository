module Api
  module V1
    class ApplicationSerializer
      include FastJsonapi::ObjectSerializer
      include JsonApiSchema

      set_id :uuid

      attributes :name
    end
  end
end
