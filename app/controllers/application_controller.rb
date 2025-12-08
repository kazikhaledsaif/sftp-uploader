class ApplicationController < ActionController::Base
  http_basic_authenticate_with name: ENV['AUTH_USERNAME'], password: ENV['AUTH_PASSWORD'] if ENV['AUTH_USERNAME'].present?
end
