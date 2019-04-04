require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module LCBOAPI
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.0
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.
    require 'base62'
    require 'token'
    require 'secure_compare'
    require 'lcbo'
    require 'magiq'
    require 'geo_scope'
    require 'redis_abuse'
    require 'api_constraint'
    require 'v1/query_helper'
    require 'v1/exporter'
    require 'boticus'
    require 'data_migrator'
    require 'crawler'
    require 'image_cacher'

    config.generators do |g|
      g.assets false
      g.helper false
      g.view_specs false
    end

    config.active_record.schema_format = :sql
  end

  def self.[](key)
    Rails.application.secrets.send(key)
  end

  def self.recache
    rid = _cache_stamp
    $redis.set('lcboapi:cache_stamp', rid)
    rid
  end

  def self.flush
    recache
    ENV['RAILS_ASSET_ID'] = cache_stamp
  end

  def self.revfile
    (Rails.root + 'REVISION').to_s
  end

  def self.has_revfile?
    File.exists?(revfile)
  end

  def self.revision
    if has_revfile?
      File.read(revfile).strip[0,7]
    else
      Time.now.to_i.to_s
    end
  end

  def self.last_crawl_id
    if (crawl = Crawl.order(id: :desc).first)
      crawl.id
    else
      0
    end
  end

  def self._cache_stamp
    "#{last_crawl_id}#{revision}"
  end

  def self.cache_stamp
    if (rid = $redis.get('lcboapi:cache_stamp'))
      rid
    else
      recache
    end
  end
end
