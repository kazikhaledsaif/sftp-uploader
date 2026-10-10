class ApplicationController < ActionController::Base
  if ENV["AUTH_USERNAME"].present?
    http_basic_authenticate_with name: ENV["AUTH_USERNAME"], password: ENV.fetch("AUTH_PASSWORD", "")
  end
end
