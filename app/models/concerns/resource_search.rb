module ResourceSearch
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

  HEADLINE_SEPARATOR = '&hellip;'

  SORTABLE_COLUMNS = [ :uuid, :uri, :resource_type, :title, :created_at, :updated_at ]

  class_methods do
    def sanitize(text)
      sanitize_sql_array ['?', text]
    end

    # Returns a SearchResults object
    def search(query: nil, prefix: false, language: nil, order_by: nil, page: nil, per_page: nil)
      page = page ? page.to_i : 1
      per_page = per_page ? per_page.to_i : 10

      # Return early if the pagination is invalid
      return SearchResults.new(none, 0) if per_page < 1

      # Generate query text
      config = sanitize VALID_TS_CONFIGS.include?(language) ? language : 'simple'
      query_array = (query || '').split(/\s/).map { |qq| "'#{sanitize qq}'" }
      query_array = query_array.map { |qq| "#{qq}:*" } if prefix
      query_text = "'#{query_array.join(' & ')}'"
      query_query = "#{config}, #{query_text}"

      # Cache the query so we save on this database round trip
      tsquery = SEARCH_CACHE.fetch("#{table_name}/queries/#{query_query}") do
        sanitize connection.execute("SELECT TO_TSQUERY(#{query_query});").first['to_tsquery']
      end

      # Normalize order_by string
      order_by_hash = (order_by || '').gsub(/u?u?id/, 'uuid').split(',').map do |ob|
        column, direction = if ob.starts_with?('-')
          [ ob[1..-1], :desc ]
        else
          [ ob, :asc ]
        end
        next unless SORTABLE_COLUMNS.include? column.to_sym

        { column => direction }
      end.compact.reduce({}, :merge)

      # Cache the search time so searches stay valid for some time
      order_by_string = order_by_hash.map do |column, direction|
        "#{column} #{direction}"
      end.join(', ')
      time = SEARCH_CACHE.fetch("#{table_name}/times/#{tsquery}/#{order_by_string}") do
        Time.current
      end
      now = Time.current

      # Check if the cached search is too old and should be expired
      if now - time > SEARCH_EXPIRES_IN
        time = now
        SEARCH_CACHE.write "#{table_name}/times/#{tsquery}/#{order_by_string}", time
      end

      # Generate search scope
      rank_sql_proc = order_by_hash.empty? ?
        ->(table) { ", TS_RANK_CD(\"#{table}\".\"tsvector\", #{tsquery}, 16) AS \"rank\"" } :
        ->(table) { '' }
      from_sql = if table_name == 'resources'
        <<-FROM_SQL.strip_heredoc
          (
            SELECT "resources".*#{rank_sql_proc.call 'resources'}
            FROM "resources"
            WHERE "resources"."tsvector" @@ #{tsquery}
            UNION ALL
            SELECT "resources".*#{rank_sql_proc.call 'metadata'}
            FROM "resources" INNER JOIN "metadata" ON "metadata"."resource_id" = "resources"."id"
            WHERE "metadata"."tsvector" @@ #{tsquery}
            UNION ALL
            SELECT "resources".*#{rank_sql_proc.call 'stats'}
            FROM "resources" INNER JOIN "stats" ON "stats"."resource_id" = "resources"."id"
            WHERE "stats"."tsvector" @@ #{tsquery}
          ) AS "resources"
        FROM_SQL
      else
        <<-FROM_SQL.strip_heredoc
          (
            SELECT "#{table_name}".*,
                   "resources"."title",
                   "resources"."content"#{rank_sql_proc.call table_name}
            FROM "resources" INNER JOIN "#{table_name}"
            ON "#{table_name}"."resource_id" = "resources"."id"
            WHERE "#{table_name}"."tsvector" @@ #{tsquery}
          ) AS "#{table_name}"
        FROM_SQL
      end
      skope = from(from_sql).order(order_by_hash.empty? ? { rank: :desc, id: :asc } : order_by_hash)

      # Cache the record ids
      # This incurs IO costs for all disk pages in the query result
      # If ordering by relevance (ts_rank), the ordering
      # operation would also incur the same cost,
      # so there's no way to optimize this without using
      # indices that are not yet in Postgres core
      # If ordering by some column, we could optimize
      # this to only load the relevant records each time
      ids = SEARCH_CACHE.fetch("#{table_name}/ids/#{tsquery}/#{order_by_string}/#{time}") do
        skope.pluck(:id)
      end

      # Return early if the page is invalid
      return SearchResults.new(none, ids.size) if page < 1

      # Calculate pagination
      start_index = (page - 1) * per_page
      end_index = page * per_page - 1
      ids_in_page = ids[start_index..end_index]

      # Generate headlines
      select_sql = <<-SELECT_SQL.strip_heredoc
        "#{table_name}".*,
        TS_HEADLINE(
          COALESCE("#{table_name}"."title", '') || ' ' || "#{table_name}"."content",
          #{tsquery},
          'MaxFragments = 2, MaxWords = 20,
           MinWords = 10, FragmentDelimiter = " #{HEADLINE_SEPARATOR} "'
        ) AS "ts_headline"
      SELECT_SQL
      skope = skope.select(select_sql)

      # Return the paginated scope and number of results
      SearchResults.new(ids_in_page == ids ? skope : skope.where(id: ids_in_page), ids.size)
    end
  end
end
