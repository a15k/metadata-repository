module Api
  module V1
    class ResourcesController < JsonApiController
      def index
        resources = current_application.resources

        query = resource_filter_params[:query]
        unless query.nil?
          language = resource_filter_params.fetch :language, 'simple'

          resources = resources.search(query, language).with_pg_search_highlight
        end

        render_resource resources: resources
      end

      def show
        get_resource

        render_resource
      end

      def create
        @resource = Resource.create! resource_create_params

        render_resource
      end

      def update
        get_resource.update_attributes! resource_update_params

        render_resource
      end

      def destroy
        get_resource.destroy!

        render_resource
      end

      protected

      def resource_filter_params
        params.permit(filter: [ :query, :language ]).fetch(:filter, {})
      end

      def get_resource
        @resource ||= Resource.find_by!(application: current_application, uuid: uuid_param)
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
        @resource_relationship_params ||= json_api_relationships.permit(
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

      def render_resource(resources: get_resource)
        render json: ResourceSerializer.new(resources).serializable_hash
      end
    end
  end
end
