module Api
  module V1
    class ResourcesController < ApiController
      before_action :get_resource, except: [ :index, :create, :search ]

      def index
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
    end
  end
end
