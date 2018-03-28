module Api
  module V1
    class StatsController < V1Controller
      before_action :get_stats, except: :create

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
        @stats = Stats.find_by!(uuid: params[:uuid])
      end
    end
  end
end
