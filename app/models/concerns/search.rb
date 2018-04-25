module Search
  extend ActiveSupport::Concern

  SEARCH_EXPIRES_IN = 1.day

  redis_secrets = Rails.application.secrets.redis
  SEARCH_CACHE = ActiveSupport::Cache::RedisCacheStore.new(
    url: redis_secrets[:url],
    namespace: redis_secrets[:namespaces][:search],
    expires_in: SEARCH_EXPIRES_IN
  )

  VALID_TS_CONFIGS = %w(
    simple
    danish
    dutch
    english
    finnish
    french
    german
    hungarian
    italian
    norwegian
    portuguese
    romanian
    russian
    spanish
    swedish
    turkish
  )

  HIGHLIGHT_SEPARATOR = '&hellip;'

  class_methods do
    def define_pg_search_scope(against:, scope_name: :pg_search, tsvector_column: 'tsvector')
      include PgSearch

      pg_search_scope scope_name, ->(query:, language:, order_bys:) do
        {
          query: query || '',
          against: against,
          using: {
            tsearch: {
              dictionary: VALID_TS_CONFIGS.include?(language) ? language : 'simple',
              tsvector_column: tsvector_column,
              negation: true,
              highlight: {
                MaxWords: 20,
                MinWords: 10,
                MaxFragments: 2,
                FragmentDelimiter: " #{HIGHLIGHT_SEPARATOR} "
              }
            }
          }
        }.tap do |config|
          config.merge!(
            ranked_by: 'NULL',
            order_within_rank: order_bys.map { |ob| "\"#{table_name}\".#{ob}" }.join(', ')
          ) unless order_bys.empty?
        end
      end
    end
  end
end
