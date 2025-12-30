# frozen_string_literal: true

module RequestHelpers
  # Generates a valid JWT token for testing
  #
  # @param user_id [Integer] the user ID to encode
  # @param email [String] the user's email
  # @param role [String] the user's role
  # @return [String] the JWT token
  def generate_token(user_id: 1, email: "test@example.com", role: "patient")
    payload = {
      user_id: user_id,
      email: email,
      role: role,
      first_name: "Test",
      last_name: "User"
    }
    JsonWebToken.encode(payload)
  end

  # Generates a valid refresh token for testing
  #
  # @param user_id [Integer] the user ID to encode
  # @return [String] the refresh token
  def generate_refresh_token(user_id: 1)
    JsonWebToken.encode_refresh_token({ user_id: user_id })
  end

  # Sets the Authorization header with a valid token
  #
  # @param token [String] the JWT token (optional, generates if not provided)
  # @return [Hash] the headers hash
  def auth_headers(token: nil, user_id: 1, email: "test@example.com", role: "patient")
    token ||= generate_token(user_id: user_id, email: email, role: role)
    { "Authorization" => "Bearer #{token}" }
  end

  # Parses JSON response body
  #
  # @return [Hash] the parsed JSON
  def json_response
    JSON.parse(response.body, symbolize_names: true)
  end

  # Stubs a successful response from a downstream service
  #
  # @param service [Symbol] the service name
  # @param path [String] the request path
  # @param method [Symbol] the HTTP method
  # @param response_body [Hash] the response body
  # @param status [Integer] the response status code
  def stub_service_request(service:, path:, method: :get, response_body: {}, status: 200)
    base_url = ServiceRegistry.url_for(service)

    stub_request(method, "#{base_url}#{path}")
      .to_return(
        status: status,
        body: response_body.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  # Stubs a failed response from a downstream service
  #
  # @param service [Symbol] the service name
  # @param path [String] the request path
  # @param method [Symbol] the HTTP method
  # @param error [String] the error message
  # @param status [Integer] the response status code
  def stub_service_error(service:, path:, method: :get, error: "Error", status: 500)
    base_url = ServiceRegistry.url_for(service)

    stub_request(method, "#{base_url}#{path}")
      .to_return(
        status: status,
        body: { error: error }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  # Stubs a timeout from a downstream service
  #
  # @param service [Symbol] the service name
  # @param path [String] the request path
  # @param method [Symbol] the HTTP method
  def stub_service_timeout(service:, path:, method: :get)
    base_url = ServiceRegistry.url_for(service)

    stub_request(method, "#{base_url}#{path}")
      .to_timeout
  end

  # Stubs authentication request to users-service
  #
  # @param email [String] the user's email
  # @param password [String] the user's password
  # @param success [Boolean] whether authentication should succeed
  # @param user_data [Hash] the user data to return on success
  def stub_authentication(email:, password:, success: true, user_data: nil)
    user_data ||= {
      id: 1,
      email: email,
      first_name: "Test",
      last_name: "User",
      role: "patient"
    }

    if success
      stub_service_request(
        service: :users,
        path: "/api/internal/authenticate",
        method: :post,
        response_body: user_data,
        status: 200
      )
    else
      stub_service_error(
        service: :users,
        path: "/api/internal/authenticate",
        method: :post,
        error: "Invalid credentials",
        status: 401
      )
    end
  end
end
