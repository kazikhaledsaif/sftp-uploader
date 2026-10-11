require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module FtpUploder
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments/, which are processed later.
    #
    # Dates like "watched on" use this zone (e.g. Asia/Kolkata). Set TIME_ZONE in .env.
    config.time_zone = ENV.fetch("TIME_ZONE", "UTC")
    # config.eager_load_paths << Rails.root.join("extras")

    # aria2 does the downloading, so no Redis/Sidekiq is needed.
    config.active_job.queue_adapter = :async
  end
end
