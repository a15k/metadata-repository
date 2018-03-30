module Api
  module V1
    class ResourcesController < JsonApiController
      before_action :get_resource, except: [ :index, :create, :search ]

      def index
        render json: ResourceSerializer.new(current_application.resources).serializable_hash
      end

      def show
        render json: ResourceSerializer.new(@resource).serializable_hash
      end

      def create
        uuid = resource_params.fetch(:id) { SecureRandom.uuid }
        application_user = current_application.application_users.find_by(
          uuid: resource_relationship_params[:application_user_id]
        )
        format = Format.find_or_create_by!(name: resource_relationship_params[:format_id]) \
          unless resource_relationship_params[:format_id].nil?
        language = Language.find_or_create_by!(name: resource_relationship_params[:language_id]) \
          unless resource_relationship_params[:language_id].nil?

        @resource = Resource.create! resource_params.merge(
          application: current_application,
          application_user: application_user,
          format: format,
          language: language
        )

        render json: ResourceSerializer.new(@resource).serializable_hash
      end

      def update
      end

      def destroy
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
          :application_id,
          :application_user_id,
          :format_id,
          :language_id
        )
      end
    end
  end
end
