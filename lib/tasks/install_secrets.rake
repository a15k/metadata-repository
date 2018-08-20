require 'aws-sdk-ssm'

desc <<-DESC.strip_heredoc
  Pull the secrets for this environment and application from the AWS Parameter
  Store and use them to write them to secrets files (secrets.yml, database.yml)
DESC
task :install_secrets, [] do
  # Secrets live in the AWS Parameter Store under a /env_name/parameter_namespace/
  # hierarchy.  Several environment variables are set by the AWS cloudformation scripts.
  #
  # This script would take the following Parameter Store values:
  #
  #   /qa/metadata/secret_key = 123456
  #   /qa/metadata/redis/namespace = metadata-dev
  #
  # and (over)write the following to config/secrets.yml:
  #
  #   production:
  #     secret_key: 123456
  #     redis:
  #       namespace: metadata-dev

  region = get_env_var!('REGION')
  env_name = get_env_var!('ENV_NAME')
  namespace = get_env_var!('PARAMETER_NAMESPACE')

  secrets = {}

  client = Aws::SSM::Client.new(region: region)
  client.get_parameters_by_path({path: "/#{env_name}/#{namespace}/",
                                 recursive: true,
                                 with_decryption: true}).each do |response|
    response.parameters.each do |parameter|
      # break out the flattened keys and ignore the env name and namespace
      keys = parameter.name.split('/').reject(&:blank?)[2..-1]
      deep_populate(secrets, keys, parameter.value)
    end
  end

  database_secrets = secrets.delete('database')

  File.open(File.expand_path("config/database.yml"), "w") do |file|
    file.write(yaml({
      'production' => {
        'database' => database_secrets['name'],
        'host' => database_secrets['host'],
        'port' => database_secrets['port'],
        'adapter' => "postgresql",
        'username' => database_secrets['username'],
        'password' => database_secrets['password']
      }
    }))
  end

  File.open(File.expand_path("config/secrets.yml"), "w") do |file|
    file.write(yaml({'production' => secrets}))
  end
end

def yaml(hash)
  # write the hash as yaml, getting rid of the "---\n" at the front
  hash.to_yaml[4..-1]
end

def get_env_var!(name)
  ENV[name].tap do |value|
    raise "Environment variable #{name} isn't set!" if value.nil?
  end
end

def deep_populate(hash, keys, value)
  if keys.length == 1
    hash[keys[0]] = value
  else
    hash[keys[0]] ||= {}
    deep_populate(hash[keys[0]], keys[1..-1], value)
  end
end
