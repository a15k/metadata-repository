module Api
  module V1
    class LanguageSerializer
      include FastJsonapi::ObjectSerializer

      set_id :name

      attributes :name
    end
  end
end
