module Api
  module V1
    class ResourcesController < V1Controller
      before_action :get_resource, except: :create

      def show
      end

      def create
      end

      def update
      end

      def destroy
      end

      protected

      def get_resource
        @resource = Resource.find_by!(uuid: params[:uuid])
      end
    end
  end
end
