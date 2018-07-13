module Api
  module V1
    class FormatSerializer
      include FastJsonapi::ObjectSerializer
      include JsonApiSchema

      set_id :name
    end
  end
end
