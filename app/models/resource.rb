class Resource < ApplicationRecord
  has_many :metadatas,          dependent: :destroy, inverse_of: :resource
  has_many :stats,              dependent: :destroy, inverse_of: :resource

  belongs_to :application,                           inverse_of: :resources
  belongs_to :application_user, optional: true,      inverse_of: :resources
  belongs_to :format,                                inverse_of: :resources
  belongs_to :language,         optional: true,      inverse_of: :resources

  before_validation :set_content

  validates :uuid, :uri,              presence: true, uniqueness: { scope: :application_id }
  validates :resource_type, :content, presence: true

  TSVECTOR_UPDATE_SQL = <<-TSVECTOR_UPDATE_SQL.strip_heredoc
    NEW."tsvector" = (
      WITH "ts_config" AS (
        SELECT COALESCE(
          (
            SELECT "pg_ts_config"."cfgname"
            FROM "pg_ts_config"
              INNER JOIN "languages"
                ON "pg_ts_config"."cfgname" = "languages"."name"
            WHERE "languages"."id" = NEW."language_id"
          )::regconfig, 'simple'
        ) AS "regconfig"
      )
      SELECT SETWEIGHT(TO_TSVECTOR("ts_config"."regconfig", COALESCE(NEW."title", '')), 'A') ||
             SETWEIGHT(TO_TSVECTOR("ts_config"."regconfig", NEW."content"), 'C')
      FROM "ts_config"
    )
  TSVECTOR_UPDATE_SQL

  trigger.before(:insert)                      { TSVECTOR_UPDATE_SQL }
  trigger.before(:update).of(:title, :content) { TSVECTOR_UPDATE_SQL }

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

  def self.sanitize(text)
    sanitize_sql_array ['?', text]
  end

  scope :search, ->(query: nil, prefix: false, language: nil,
                    order_by: nil, page: nil, per_page: nil) do
    page ||= 1
    per_page ||= 10

    # Return early if the pagination is invalid
    return none if page < 1 || per_page < 1

    # Generate query text
    config = sanitize VALID_TS_CONFIGS.include?(language) ? language : 'simple'
    query_array = (query || '').split(/\s/)
    query_array = query_array.map { |qq| "#{qq}:*" } if prefix
    query_text = sanitize query_array.join(' & ')
    query_query = "#{config}, #{query_text}"

    # Cache the query so we save on this database round trip
    tsquery = SEARCH_CACHE.fetch("queries/#{query_query}") do
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
    order_by_string = order_by_hash.map { |column, direction| "#{column} #{direction}" }.join(', ')
    time = SEARCH_CACHE.fetch("times/#{tsquery}/#{order_by_string}") { Time.current }
    now = Time.current

    # Check if the cached search is too old and should be expired
    if now - time > SEARCH_EXPIRES_IN
      time = now
      SEARCH_CACHE.write "times/#{tsquery}/#{order_by_string}", time
    end

    # Generate search scope
    rank_sql_proc = order_by_hash.empty? ?
      ->(table) { ", TS_RANK_CD(\"#{table}\".\"tsvector\", #{tsquery}, 16) AS \"rank\"" } :
      ->(table) { '' }
    from_sql = <<-FROM_SQL.strip_heredoc
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
    skope = from(from_sql).order(order_by_hash.empty? ? { rank: :desc, id: :asc } : order_by_hash)

    # Cache the record ids
    # This incurs IO costs for all disk pages in the query result
    # If ordering by relevance (ts_rank), the ordering operation would also incur the same cost,
    # so there's no way to optimize this without using indices that are not yet in Postgres core
    # If ordering by some column, we could optimize this to only load the relevant records each time
    ids = SEARCH_CACHE.fetch("ids/#{tsquery}/#{order_by_string}/#{time}") do
      skope.pluck(:id)
    end

    # Calculate pagination
    start_index = (page - 1) * per_page
    end_index = page * per_page - 1
    ids_in_page = ids[start_index..end_index]

    # Generate headlines
    select_sql = <<-SELECT_SQL.strip_heredoc
      "resources".*,
      TS_HEADLINE(
        COALESCE("resources"."title", '') || ' ' || "resources"."content",
        #{tsquery},
        'MaxFragments = 2, MaxWords = 20,
         MinWords = 10, FragmentDelimiter = " #{HEADLINE_SEPARATOR} "'
      ) AS "ts_headline"
    SELECT_SQL
    skope = skope.select(select_sql)

    # Return paginated scope
    ids_in_page == ids ? skope : skope.where(id: ids_in_page)
  end

  def set_content
    self.content ||= FaradayWithRedirects.get uri
  end

  def application_uuid
    application.uuid
  end

  def application_user_uuid
    application_user&.uuid
  end

  def format_name
    format.name
  end

  def language_name
    language&.name
  end

  # Like ts_headline but also adds ellipses at the beginning and end of each headline
  def headline
    return unless respond_to?(:ts_headline)

    title_and_content = "#{title} #{content}".strip
    headlines = ts_headline.split(HEADLINE_SEPARATOR)
    first_headline = headlines.first.strip.gsub(/<b>([^<]*)<\/b>/, '\1')
    last_headline = headlines.last.strip.gsub(/<b>([^<]*)<\/b>/, '\1')
    prefix = "#{HEADLINE_SEPARATOR} " unless title_and_content.starts_with?(first_headline)
    suffix = " #{HEADLINE_SEPARATOR}" unless title_and_content.ends_with?(last_headline)

    "#{prefix}#{ts_headline}#{suffix}"
  end

  def same_resource_uuid_metadatas
    @same_resource_uuid_metadatas ||= Metadata.joins(:resource).where(resources: { uuid: uuid })
  end

  def same_resource_uuid_stats
    @same_resource_uuid_stats ||= Stats.joins(:resource).where(resources: { uuid: uuid })
  end

  def reload
    @same_resource_uuid_metadatas = nil
    @same_resource_uuid_stats = nil

    super
  end
end
