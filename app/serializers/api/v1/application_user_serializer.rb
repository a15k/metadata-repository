module Api
  module V1
    class ApplicationUserSerializer
      include FastJsonapi::ObjectSerializer
      include JsonApiSchema

      set_id :uuid
    end
  end
end
