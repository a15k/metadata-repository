module Api
  module V1
    class StatsController < JsonApiController
      def index
        render_stats stats: current_application.stats
      end

      def show
        get_stats

        render_stats
      end

      def create
        @stats = Stats.create! stats_create_params

        render_stats status: 201
      end

      def update
        get_stats.update_attributes! stats_update_params

        render_stats
      end

      def destroy
        get_stats.destroy!

        render_stats
      end

      protected

      def get_stats
        @stats ||= Stats.find_by!(application: current_application, uuid: path_id_param)
      end

      def stats_attribute_params
        @stats_attribute_params ||= json_api_attributes.permit(:uuid, value: {})
      end

      def stats_relationship_params
        @stats_relationship_params ||= json_api_relationships.permit(
          :application_user_id,
          :resource_id,
          :format_id
        )
      end

      def stats_update_params
        @stats_update_params ||= stats_attribute_params.except(:uuid).tap do |hash|
          hash[:application_user] = current_application.application_users.find_by(
            uuid: stats_relationship_params[:application_user_id]
          ) if stats_relationship_params.has_key? :application_user_id
          hash[:resource] = current_application.resources.find_by(
            uuid: stats_relationship_params[:resource_id]
          ) if stats_relationship_params.has_key? :resource_id
          hash[:format] = Format.find_or_create_by!(
            name: stats_relationship_params[:format_id]
          ) if stats_relationship_params.has_key? :format_id
        end
      end

      def stats_create_params
        @stats_create_params ||= stats_update_params.merge(
          application: current_application,
          uuid: stats_attribute_params[:uuid]
        )
      end

      def render_stats(stats: get_stats, status: 200)
        render json: StatsSerializer.new(stats).serializable_hash, status: status
      end
    end
  end
end
