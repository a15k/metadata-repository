module Api
  module V1
    class MetadatasController < JsonApiController
      def index
        render_metadata metadatas: current_application.metadatas
      end

      def show
        get_metadata

        render_metadata
      end

      def create
        @metadata = Metadata.create! metadata_create_params

        render_metadata
      end

      def update
        get_metadata.update_attributes! metadata_update_params

        render_metadata
      end

      def destroy
        get_metadata.destroy!

        render_metadata
      end

      protected

      def get_metadata
        @metadata ||= Metadata.find_by!(application: current_application, uuid: path_id_param)
      end

      def metadata_attribute_params
        @metadata_attribute_params ||= json_api_attributes.permit(:uuid, value: {})
      end

      def metadata_relationship_params
        @metadata_relationship_params ||= json_api_relationships.permit(
          :application_user_id,
          :resource_id,
          :format_id
        )
      end

      def metadata_update_params
        @metadata_update_params ||= metadata_attribute_params.except(:uuid).tap do |hash|
          hash[:application_user] = current_application.application_users.find_by(
            uuid: metadata_relationship_params[:application_user_id]
          ) if metadata_relationship_params.has_key? :application_user_id
          hash[:resource] = current_application.resources.find_by(
            uuid: metadata_relationship_params[:resource_id]
          ) if metadata_relationship_params.has_key? :resource_id
          hash[:format] = Format.find_or_create_by!(
            name: metadata_relationship_params[:format_id]
          ) if metadata_relationship_params.has_key? :format_id
        end
      end

      def metadata_create_params
        @metadata_create_params ||= metadata_update_params.merge(
          application: current_application,
          uuid: metadata_attribute_params[:uuid]
        )
      end

      def render_metadata(metadatas: get_metadata)
        render json: MetadataSerializer.new(metadatas).serializable_hash
      end
    end
  end
end
