# frozen_string_literal: true

class ApplicationController < ActionController::API
  include ErrorHandler

  # Catch-all for undefined routes
  def route_not_found
    render json: ErrorResponse.not_found(
      "The requested endpoint does not exist",
      request_id: request.request_id
    ), status: :not_found
  end
end
