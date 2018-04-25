class Resource < ApplicationRecord
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
             SETWEIGHT(TO_TSVECTOR("ts_config"."regconfig", NEW."content"), 'D')
      FROM "ts_config"
    )
  TSVECTOR_UPDATE_SQL

  trigger.before(:insert)                      { TSVECTOR_UPDATE_SQL }
  trigger.before(:update).of(:title, :content) { TSVECTOR_UPDATE_SQL }

  include Search

  define_pg_search_scope against: { title: 'A', content: 'D' }

  SORTABLE_COLUMNS = [ :uuid, :uri, :resource_type, :title, :created_at, :updated_at ]

  scope :search, ->(query: nil, language: nil, order_by: nil, page: nil, per_page: nil) do
    page ||= 1
    per_page ||= 10
    return none if page < 1 || per_page < 1

    normalized_order_bys = (order_by || '').gsub(/u?u?id/, 'uuid').split(',').map do |ob|
      column, direction = if ob.starts_with?('-')
        [ ob[1..-1], 'DESC' ]
      else
        [ ob, 'ASC' ]
      end
      next unless SORTABLE_COLUMNS.include? column.to_sym

      "\"#{column}\" #{direction}"
    end.compact

    skope = pg_search(query: query, language: language, order_bys: normalized_order_bys)
              .with_pg_search_highlight

    query = skope.tsearch.send :tsquery

    # Cache the query so we save on this database round trip
    tsquery = SEARCH_CACHE.fetch("queries/#{query}") { connection.execute("SELECT #{query}").first }

    # Cache the search time so searches stay valid for some time
    normalized_order_by_string = normalized_order_bys.join(', ')
    time = SEARCH_CACHE.fetch("times/#{tsquery}/#{normalized_order_by_string}") { Time.current }
    now = Time.current

    # Check if the cached search is too old and should be expired
    if now - time > SEARCH_EXPIRES_IN
      time = now
      SEARCH_CACHE.write "times/#{tsquery}/#{normalized_order_by_string}", time
    end

    # Cache the record ids
    # This incurs IO costs for all disk pages in the query result
    # If ordering by relevance (ts_rank), the ordering operation would also incur the same cost,
    # so there's no way to optimize this without using indices that are not yet in Postgres core
    # If ordering by some column, we could optimize this to only load the relevant records each time
    ids = SEARCH_CACHE.fetch("ids/#{tsquery}/#{normalized_order_by_string}/#{time}") do
      skope.pluck :id
    end

    # Apply pagination
    start_index = (page - 1) * per_page
    end_index = page * per_page - 1
    ids_in_page = ids[start_index..end_index]

    # Generate scope that will load records in the page
    ids_in_page == ids ? skope : skope.where(id: ids_in_page)
  end

  has_many :metadatas,          dependent: :destroy, inverse_of: :resource
  has_many :stats,              dependent: :destroy, inverse_of: :resource

  belongs_to :application,                           inverse_of: :resources
  belongs_to :application_user, optional: true,      inverse_of: :resources
  belongs_to :format,                                inverse_of: :resources
  belongs_to :language,         optional: true,      inverse_of: :resources

  before_validation :set_content

  validates :uuid, :uri,              presence: true, uniqueness: { scope: :application_id }
  validates :resource_type, :content, presence: true

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

  # Like pg_search_highlight but also adds ellipses at the beginning and end of the highlight
  def highlight
    return unless respond_to?(:pg_search_highlight)

    title_and_content = "#{title} #{content}".strip
    highlights = pg_search_highlight.split(HIGHLIGHT_SEPARATOR)
    first_highlight = highlights.first.strip.gsub(/<b>([^<]*)<\/b>/, '\1')
    last_highlight = highlights.last.strip.gsub(/<b>([^<]*)<\/b>/, '\1')
    prefix = "#{HIGHLIGHT_SEPARATOR} " unless title_and_content.starts_with?(first_highlight)
    suffix = " #{HIGHLIGHT_SEPARATOR}" unless title_and_content.ends_with?(last_highlight)

    "#{prefix}#{pg_search_highlight}#{suffix}"
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
