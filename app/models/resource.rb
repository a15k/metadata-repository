class Resource < ApplicationRecord
  SORTABLE_COLUMNS = [ :uuid, :uri, :resource_type, :title, :created_at, :updated_at ]

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

  include PgSearch

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

  pg_search_scope :search, ->(query: nil, language: nil, order_by: nil) do
    query ||= ''
    language ||= 'simple'
    order_by ||= ''

    order_bys = order_by.gsub(/u?u?id/, 'uuid').split(',').map do |ob|
      column, direction = if ob.starts_with?('-')
        [ ob[1..-1], 'DESC' ]
      else
        [ ob, 'ASC' ]
      end
      next unless SORTABLE_COLUMNS.include? column.to_sym

      [ column, direction ]
    end.compact
    ranked_by = order_bys.empty? ? ':tsearch' : 'NULL'
    order_within_rank = order_bys.empty? ? '"resources"."id" ASC' : order_bys.map do |ob|
      "\"resources\".\"#{ob.first}\" #{ob.second}"
    end.join(', ')

    {
      query: query,
      against: { title: 'A', content: 'D' },
      using: {
        tsearch: {
          dictionary: VALID_TS_CONFIGS.include?(language) ? language : 'simple',
          tsvector_column: 'tsvector',
          negation: true,
          highlight: {
            MaxWords: 20,
            MinWords: 10,
            MaxFragments: 2,
            FragmentDelimiter: " #{HIGHLIGHT_SEPARATOR} "
          }
        }
      },
      ranked_by: ranked_by,
      order_within_rank: order_within_rank
    }
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
