module Api
  module V1
    class MetadatasController < JsonApiController
      before_action :get_metadata, except: [ :index, :create ]

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

      protected

      def get_metadata
        @metadata = Metadata.find_by!(application: current_application, uuid: uuid_param)
      end

      def metadata_params
        json_api_attributes.permit(
          :id,
          :value,
          application: :id,
          application_user: :id,
          resource: :id,
          format: :name
        )
      end
    end
  end
end
