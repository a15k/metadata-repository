module Api
  module V1
    class MetadatasController < ApiController
      before_action :get_metadata, except: :create

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
        @metadata = Metadata.find_by!(uuid: params[:uuid])
      end
    end
  end
end
