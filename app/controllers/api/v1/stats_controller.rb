module Api
  module V1
    class StatsController < JsonApiController
      before_action :can_modify!, only: [ :update, :destroy ]

      def search
        search_results = Stats.search(
          query: filter_params[:query],
          language: filter_params[:language],
          order_by: params[:sort],
          page: page_params[:number],
          per_page: page_params[:size]
        )
        stats = search_results.items.preload(unscoped_resources: :unscoped_metadatas).to_a
        stats.each { |stat| stat.scoped_to_application = current_application }

        render_stats stats: stats, meta: { count: search_results.count }
      end

      def index
        render_stats stats: resource.same_resource_uuid_stats
      end

      def show
        render_stats
      end

      def create
        @stats = Stats.create! stats_create_params

        render_stats status: :created
      end

      def update
        stats.update_attributes! stats_update_params

        render_stats
      end

      def destroy
        stats.destroy!

        render_stats
      end

      protected

      def resource
        @resource ||= Resource.find_by(
          application: current_application, uuid: params[:resource_uuid]
        ) || Resource.order(:id).find_by!(uuid: params[:resource_uuid])
      end

      def stats
        @stats ||= resource.same_resource_uuid_stats.find_by(
          application: current_application, uuid: path_id_param
        ) || resource.same_resource_uuid_stats.order(:id).find_by!(uuid: path_id_param)
      end

      def can_modify!
        raise SecurityTransgression, stats unless stats.application == current_application
      end

      def stats_attribute_params
        @stats_attribute_params ||= json_api_attributes.permit(:uuid, value: {})
      end

      def stats_relationship_params
        @stats_relationship_params ||= json_api_relationships_to_one.permit(
          :application_user_id,
          :resource_id,
          :format_id,
          :language_id
        )
      end

      def stats_update_params
        @stats_update_params ||= stats_attribute_params.except(:uuid).tap do |hash|
          hash[:application_user] = current_application.application_users.find_by(
            uuid: stats_relationship_params[:application_user_id]
          ) if stats_relationship_params.has_key? :application_user_id
          hash[:format] = Format.find_or_create_by!(
            name: stats_relationship_params[:format_id]
          ) if stats_relationship_params.has_key? :format_id
          hash[:language] = Language.find_or_create_by!(
            name: stats_relationship_params[:language_id]
          ) if stats_relationship_params.has_key? :language_id
        end
      end

      def stats_create_params
        @stats_create_params ||= stats_update_params.merge(
          application: current_application,
          resource: resource,
          uuid: stats_attribute_params[:uuid]
        )
      end

      def render_stats(stats: nil, status: :ok, **options)
        stats ||= send :stats

        render json: StatsSerializer.new(
          stats, options.merge(include: [ :'resource.metadatas' ])
        ).serializable_hash, status: status
      end
    end
  end
end
