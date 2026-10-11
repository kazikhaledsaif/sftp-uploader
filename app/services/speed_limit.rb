# How much of the internet connection downloads may use.
#
#   full      no limit
#   balanced  about 60% of the fastest speed seen, the rest stays free
#   light     about 30%
#
# The fastest speed is learned automatically while on "full" (the line's
# real capacity). Until then, fixed fallback limits are used.
module SpeedLimit
  MODES = { "full" => nil, "balanced" => 0.6, "light" => 0.3 }.freeze
  LABELS = { "full" => "Full speed", "balanced" => "Balanced", "light" => "Light" }.freeze
  FALLBACK = { "balanced" => 5 * 1024**2, "light" => 2 * 1024**2 }.freeze # bytes/s, before any measurement

  module_function

  def mode
    Setting["speed_mode"].presence_in(MODES.keys) || "full"
  end

  # Fastest total download speed seen on "full" (bytes/s), 0 if unknown.
  def peak
    Setting["peak_speed"].to_i
  end

  # Limit in bytes/s for a mode; 0 means unlimited.
  def limit_for(name)
    share = MODES[name]
    return 0 unless share

    peak.positive? ? (peak * share).to_i : FALLBACK[name]
  end

  def set!(name)
    raise ArgumentError, "unknown speed mode #{name.inspect}" unless MODES.key?(name)

    Setting["speed_mode"] = name
    apply!
  end

  # Tell aria2 the current limit. Safe to call often (aria2 forgets it on restart).
  def apply!(client = Aria2Client.new)
    client.call("aria2.changeGlobalOption", { "max-overall-download-limit" => limit_for(mode).to_s })
    true
  rescue Aria2Client::Error => e
    Rails.logger.warn("Could not set the download speed limit: #{e.message}")
    false
  end

  # Called with the current total speed; remembers a new best while on "full".
  def record(total_speed)
    return unless mode == "full" && total_speed > peak * 1.05 # avoid a write for every tiny change

    Setting["peak_speed"] = total_speed
  end
end
