module Api
  module V1
    class FormatSerializer
      include FastJsonapi::ObjectSerializer

      set_id :name

      attributes :name
    end
  end
end
