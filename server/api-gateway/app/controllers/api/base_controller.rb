# frozen_string_literal: true

module Api
  # Base controller for all API endpoints
  # Provides common functionality for API versioning and service proxying
  class BaseController < ApplicationController
    include Authenticatable
    include ErrorHandler

    # Set request context for downstream services
    before_action :set_request_context

    protected

    # Proxies a request to a downstream service
    #
    # @param service [Symbol] the target service
    # @param path [String] the request path
    # @param method [Symbol] HTTP method (:get, :post, :put, :patch, :delete)
    # @param body [Hash, nil] request body for POST/PUT/PATCH
    # @param params [Hash] query parameters
    # @return [void]
    def proxy_request(service:, path:, method: :get, body: nil, params: {})
      response = case method
      when :get
                   HttpClient.get(service, path, params: params, headers: proxy_headers)
      when :post
                   HttpClient.post(service, path, body, headers: proxy_headers)
      when :put
                   HttpClient.put(service, path, body, headers: proxy_headers)
      when :patch
                   HttpClient.patch(service, path, body, headers: proxy_headers)
      when :delete
                   HttpClient.delete(service, path, headers: proxy_headers)
      end

      render_proxy_response(response)
    end

    # Renders the proxied response from downstream service
    #
    # @param response [HttpClient::Response] the response from downstream service
    def render_proxy_response(response)
      render json: response.body, status: response.status
    end

    # Headers to forward to downstream services
    def proxy_headers
      headers = {
        "X-Request-ID" => request_id,
        "X-Forwarded-For" => request.remote_ip
      }

      # Forward user info if authenticated
      if authenticated?
        headers["X-User-ID"] = current_user_id.to_s
        headers["X-User-Email"] = current_user[:email] if current_user[:email].present?
        headers["X-User-Role"] = current_user[:role] if current_user[:role].present?
      end

      # Forward authorization header for services that need to verify tokens
      if request.headers["Authorization"].present?
        headers["Authorization"] = request.headers["Authorization"]
      end

      headers
    end

    # Get current request ID
    def request_id
      request.request_id || Thread.current[:request_id]
    end

    private

    # Sets thread-local request context for use in services
    def set_request_context
      Thread.current[:request_id] = request_id
      Thread.current[:current_user_id] = current_user_id if authenticated?
    end
  end
end
