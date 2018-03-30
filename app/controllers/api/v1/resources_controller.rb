module Api
  module V1
    class ResourcesController < JsonApiController
      before_action :get_resource, except: [ :index, :create, :search ]

      def index
        render_resource resources: current_application.resources
      end

      def show
        render_resource
      end

      def create
        @resource = Resource.create! create_or_update_params.merge(application: current_application)

        render_resource
      end

      def update
        @resource.update_attributes! create_or_update_params

        render_resource
      end

      def destroy
        @resource.destroy!

        render_resource
      end

      def search
      end

      protected

      def get_resource
        @resource = Resource.find_by!(application: current_application, uuid: uuid_param)
      end

      def resource_params
        @resource_params ||= json_api_attributes.permit(
          :uuid,
          :uri,
          :resource_type,
          :title,
          :content
        )
      end

      def resource_relationship_params
        @relationship_params ||= json_api_relationships.permit(
          :application_user_id,
          :format_id,
          :language_id
        )
      end

      def create_or_update_params
        @create_or_update_params ||= resource_params.dup.tap do |hash|
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

      def render_resource(resources: @resource)
        render json: ResourceSerializer.new(resources).serializable_hash
      end
    end
  end
end
