# Keeps download status fresh and runs automatic retries even when nobody has
# the page open. Only in the web server (not console, rake or asset builds).
if defined?(Rails::Server) && ENV["SECRET_KEY_BASE_DUMMY"].blank?
  Rails.application.config.after_initialize do
    Thread.new do
      Thread.current.name = "aria2-sync"
      loop do
        sleep 5
        Rails.application.executor.wrap { Engines::Aria2Engine.new.sync(Download.active.to_a) }
      rescue StandardError => e
        Rails.logger.warn("Background aria2 sync failed: #{e.message}")
      end
    end
  end
end
