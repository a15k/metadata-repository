module Api
  module V1
    class ApplicationUserSerializer
      include FastJsonapi::ObjectSerializer

      set_id :uuid
    end
  end
end
