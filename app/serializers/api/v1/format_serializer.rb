module Api
  module V1
    class FormatSerializer
      include FastJsonapi::ObjectSerializer

      set_id :name
    end
  end
end
