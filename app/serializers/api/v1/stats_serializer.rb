module Api
  module V1
    class StatsSerializer
      include FastJsonapi::ObjectSerializer

      set_id :uuid

      attributes :value

      belongs_to :application,      id_method_name: :application_uuid
      belongs_to :application_user, id_method_name: :application_user_uuid
      belongs_to :resource,         id_method_name: :resource_uuid
      belongs_to :format,           id_method_name: :format_name
    end
  end
end
