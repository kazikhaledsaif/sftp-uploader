# Keeps download status fresh and runs automatic retries even when nobody has
# the page open. Only in the web server (not console, rake or asset builds).
if defined?(Rails::Server) && ENV["SECRET_KEY_BASE_DUMMY"].blank?
  Rails.application.config.after_initialize do
    Thread.new do
      Thread.current.name = "aria2-sync"
      ticks = 0
      loop do
        sleep 5
        Rails.application.executor.wrap do
          # aria2 forgets the speed limit when it restarts: re-apply it every minute.
          SpeedLimit.apply! if (ticks % 12).zero?
          Engines::Aria2Engine.new.sync(Download.active.to_a)
        end
        ticks += 1
      rescue StandardError => e
        Rails.logger.warn("Background aria2 sync failed: #{e.message}")
      end
    end
  end
end
