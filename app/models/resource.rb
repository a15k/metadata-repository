class Resource < ApplicationRecord
  include ApplicationScoping
  include ResourceSearch

  scoped_has_many :metadatas,   dependent: :destroy, inverse_of: :resource
  scoped_has_many :stats,       dependent: :destroy, inverse_of: :resource

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

  def set_content
    if uri.present?
      self.content ||= FaradayWithRedirects.get uri
    end
  end

  def metadata_uuids
    metadatas.map(&:uuid).uniq
  end

  def stats_uuids
    stats.map(&:uuid).uniq
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
