module Api
  module V1
    class ResourcesController < JsonApiController
      before_action :get_resource, except: [ :index, :create, :search ]

      def index
        resource_params
      end

      def show
      end

      def create
      end

      def update
      end

      def destroy
      end

      def search
      end

      protected

      def get_resource
        @resource = Resource.find_by!(application: current_application, uuid: uuid_param)
      end

      def resource_params
        json_api_attributes.permit(
          :id,
          :uri,
          :resource_type,
          :title,
          :content,
          application: :id,
          application_user: :id,
          format: :name,
          language: :name
        )
      end
    end
  end
end
