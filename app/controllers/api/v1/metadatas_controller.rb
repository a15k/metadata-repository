module Api
  module V1
    class MetadatasController < JsonApiController
      before_action :can_modify!, only: [ :update, :destroy ]

      def index
        render_metadata metadatas: resource.same_resource_uuid_metadatas
      end

      def show
        render_metadata
      end

      def create
        @metadata = Metadata.create! metadata_create_params

        render_metadata status: :created
      end

      def update
        metadata.update_attributes! metadata_update_params

        render_metadata
      end

      def destroy
        metadata.destroy!

        render_metadata
      end

      protected

      def resource
        @resource ||= Resource.find_by(
          application: current_application, uuid: params[:resource_uuid]
        ) || Resource.order(:id).find_by!(uuid: params[:resource_uuid])
      end

      def metadata
        @metadata ||= resource.same_resource_uuid_metadatas.find_by(
          application: current_application, uuid: path_id_param
        ) || resource.same_resource_uuid_metadatas.order(:id).find_by!(uuid: path_id_param)
      end

      def can_modify!
        raise SecurityTransgression, metadata unless metadata.application == current_application
      end

      def metadata_attribute_params
        @metadata_attribute_params ||= json_api_attributes.permit(:uuid, value: {})
      end

      def metadata_relationship_params
        @metadata_relationship_params ||= json_api_relationships.permit(
          :application_user_id,
          :resource_id,
          :format_id,
          :language_id
        )
      end

      def metadata_update_params
        @metadata_update_params ||= metadata_attribute_params.except(:uuid).tap do |hash|
          hash[:application_user] = current_application.application_users.find_by(
            uuid: metadata_relationship_params[:application_user_id]
          ) if metadata_relationship_params.has_key? :application_user_id
          hash[:format] = Format.find_or_create_by!(
            name: metadata_relationship_params[:format_id]
          ) if metadata_relationship_params.has_key? :format_id
          hash[:language] = Language.find_or_create_by!(
            name: metadata_relationship_params[:language_id]
          ) if metadata_relationship_params.has_key? :language_id
        end
      end

      def metadata_create_params
        @metadata_create_params ||= metadata_update_params.merge(
          application: current_application,
          resource: resource,
          uuid: metadata_attribute_params[:uuid]
        )
      end

      def render_metadata(metadatas: metadata, status: :ok)
        render json: MetadataSerializer.new(metadatas).serializable_hash, status: status
      end
    end
  end
end
