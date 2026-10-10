require "uri"

# Works out a file extension from the URL, then the
# Content-Disposition header, then the Content-Type header.
module FileExtension
  module_function

  def detect(url, content_disposition = nil, content_type = nil)
    ext = File.extname(URI.parse(url).path.to_s) rescue ""
    return ext if ext.present?

    if content_disposition.present?
      name = content_disposition[/filename\*?=(?:UTF-8'')?"?([^";]+)"?/i, 1]
      ext = File.extname(URI.decode_www_form_component(name.to_s)) if name
      return ext if ext.present?
    end

    if content_type.present?
      mime = MiniMime.lookup_by_content_type(content_type.split(";").first.strip)
      return ".#{mime.extension}" if mime&.extension.present?
    end

    ""
  end
end
