source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 5.2.0'

# Use PostgreSQL as the database for Active Record
gem 'pg'

# Use Puma as the app server
gem 'puma', '~> 3.7'

# Use Redis for caching
gem 'redis', '~> 4.0'
gem 'hiredis'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.1.0', require: false

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin AJAX possible
gem 'rack-cors'

# respond_to controller class method
gem 'responders'

# HTTP Requests
gem 'faraday'
gem 'faraday_middleware'

# Database triggers
gem 'hairtrigger'

# Fast JSON parsing and rendering
gem 'oj'
gem 'oj_mimic_json'
gem 'fast_jsonapi'

# API versioning
gem 'versionist'

# Webpack integration
gem 'webpacker'

# API docs
gem 'rswag'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]

  # Use RSpec for tests
  gem 'rspec-rails'

  # Model factories for tests
  gem 'factory_bot_rails'

  # Fake data for tests
  gem 'faker'
end

group :development do
  gem 'listen', '>= 3.0.5', '< 3.2'
  # Spring speeds up development by keeping your application running in the background.
  # Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
end

group :test do
  # Test database cleanup
  gem 'database_cleaner'

  # Test helpers
  gem 'shoulda-matchers'

  # Mock HTTP requests
  gem 'webmock'

  # Record and replay HTTP requests
  gem 'vcr'
end
