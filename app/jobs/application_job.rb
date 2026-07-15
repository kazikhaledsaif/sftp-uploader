class ApplicationJob < ActiveJob::Base
  # Automatically retry when SQLite is temporarily locked.
  retry_on ActiveRecord::StatementInvalid, wait: 5.seconds, attempts: 5

  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError
end
