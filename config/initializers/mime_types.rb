# The app manifest (public/manifest.webmanifest) needs its own type so phones
# recognise Popcorn as an installable app.
Rack::Mime::MIME_TYPES[".webmanifest"] = "application/manifest+json"
