require_relative 'boot'

require "rails"

require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module MetadataRepository
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.2

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    # Set the default cache store to Redis
    # This setting cannot live in an initializer
    # See https://github.com/rails/rails/issues/10908
    redis_secrets = Rails.application.secrets.redis
    config.cache_store = :redis_cache_store, {
      url: redis_secrets[:url],
      namespace: redis_secrets[:namespaces][:cache]
    } if redis_secrets.present? # won't be when installing prod secrets via install_secrets

    config.after_initialize do
      # Make sure the mothership application exists if we have its secrets
      mothership_application_secrets = Rails.application.secrets['mothership_application']

      begin
        ::Application.find_or_create_by(
          name: "a15k Mothership",
          uuid: mothership_application_secrets[:uuid],
          token: mothership_application_secrets[:token]
        ) if mothership_application_secrets.present?
      rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError => ee
        # Likely because database not yet created, all good
      end
    end
  end
end
