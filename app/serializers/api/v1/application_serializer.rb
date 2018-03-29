module Api
  module V1
    class ApplicationSerializer
      include FastJsonapi::ObjectSerializer

      set_id :uuid

      attributes :uuid, :name
    end
  end
end
