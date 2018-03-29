module Api
  module V1
    class ApplicationUserSerializer
      include FastJsonapi::ObjectSerializer

      set_id :uuid

      attributes :uuid
    end
  end
end
