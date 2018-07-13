module Api
  module V1
    class ApplicationUsersController < JsonApiController
      def index
        render_application_user application_users: current_application.application_users
      end

      def show
        render_application_user
      end

      def create
        @application_user = ApplicationUser.create! application_user_create_params

        render_application_user status: 201
      end

      def update
        application_user.update_attributes! application_user_update_params

        render_application_user
      end

      def destroy
        application_user.destroy!

        render_application_user
      end

      protected

      def application_user_filter_params
        params.permit(filter: [ :query, :language ]).fetch(:filter, {})
      end

      def application_user
        @application_user ||= ApplicationUser.find_by!(
          application: current_application, uuid: path_id_param
        )
      end

      def application_user_attribute_params
        @application_user_attribute_params ||= json_api_attributes(required: false).permit(:uuid)
      end

      def application_user_create_params
        @application_user_create_params ||= application_user_attribute_params.merge(
          application: current_application
        )
      end

      def render_application_user(application_users: application_user, status: 200)
        render json: ApplicationUserSerializer.new(application_users).serializable_hash,
               status: status
      end
    end
  end
end
