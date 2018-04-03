module Api
  module V1
    class LanguageSerializer
      include FastJsonapi::ObjectSerializer
      include JsonApiSchema

      set_id :name
    end
  end
end
