# SQLite allows one writer at a time. With sqlite3 1.x, the normal busy timeout
# waits while holding Ruby's global lock, so the thread that owns the write
# lock cannot finish and the waiter fails with "database is locked".
# This handler sleeps between retries instead, letting other threads run.
module SqliteBusyHandler
  RETRY_SLEEP = 0.01 # seconds
  MAX_WAIT = 10.0    # seconds

  private

  def configure_connection
    super
    raw_connection.busy_handler do |count|
      next false if count * RETRY_SLEEP >= MAX_WAIT

      sleep RETRY_SLEEP
      true
    end
  end
end

ActiveSupport.on_load(:active_record_sqlite3adapter) do
  prepend SqliteBusyHandler
end
