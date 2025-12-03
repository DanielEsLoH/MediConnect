class ApplicationController < ActionController::API
  before_action :set_request_id

  private

  def set_request_id
    Current.request_id = request.headers["X-Request-ID"] || SecureRandom.uuid
    response.headers["X-Request-ID"] = Current.request_id
  end
end
