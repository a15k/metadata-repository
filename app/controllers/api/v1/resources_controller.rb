module Api
  module V1
    class ResourcesController < JsonApiController

      before_action :can_modify!, only: [ :update, :destroy ]

      def index
        render_resource resources: Resource.search(
          query: filter_params[:query],
          page: filter_params[:page],
          per_page: filter_params[:per_page],
          language: filter_params[:language],
          order_by: params[:sort]
        ).preload(:unscoped_metadatas, :unscoped_stats).each do |resource|
          resource.scoped_to_application = current_application
        end
      end

      def show
        render_resource
      end

      def create
        @resource = Resource.create! resource_create_params

        render_resource status: :created
      end

      def update
        resource.update_attributes! resource_update_params

        render_resource
      end

      def destroy
        resource.destroy!

        render_resource
      end

      protected

      def resource
        @resource ||= Resource.find_by(application: current_application, uuid: path_id_param) ||
                      Resource.order(:id).find_by!(uuid: path_id_param)
      end

      def can_modify!
        raise SecurityTransgression, resource unless resource.application == current_application
      end

      def resource_attribute_params
        @resource_attribute_params ||= json_api_attributes.permit(
          :uuid,
          :uri,
          :resource_type,
          :title,
          :content
        )
      end

      def resource_relationship_params
        @resource_relationship_params ||= json_api_relationships_to_one.permit(
          :application_user_id,
          :format_id,
          :language_id
        )
      end

      def resource_update_params
        @resource_update_params ||= resource_attribute_params.except(:uuid).tap do |hash|
          hash[:application_user] = current_application.application_users.find_by(
            uuid: resource_relationship_params[:application_user_id]
          ) if resource_relationship_params.has_key? :application_user_id
          hash[:format] = Format.find_or_create_by!(
            name: resource_relationship_params[:format_id]
          ) if resource_relationship_params.has_key? :format_id
          hash[:language] = Language.find_or_create_by!(
            name: resource_relationship_params[:language_id]
          ) if resource_relationship_params.has_key? :language_id
        end
      end

      def resource_create_params
        @resource_create_params ||= resource_update_params.merge(
          application: current_application,
          uuid: resource_attribute_params[:uuid]
        )
      end

      def render_resource(resources: resource, status: :ok)
        render json: ResourceSerializer.new(
          resources, include: [ :metadatas, :stats ]
        ).serializable_hash, status: status
      end
    end
  end
end
