module Api
  module V1
    class StatsController < ApiController
      before_action :get_stats, except: [ :index, :create ]

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

      def get_stats
        @stats = Stats.find_by!(application: current_application, uuid: uuid_param)
      end
    end
  end
end
