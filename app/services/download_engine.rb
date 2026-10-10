# aria2 downloads files straight into the mounted media folders.
module DownloadEngine
  module_function

  def current
    Engines::Aria2Engine.new
  end
end
