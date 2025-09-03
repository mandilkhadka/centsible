class ApplicationController < ActionController::Base
  before_action :set_active_storage_url_options

  private

  def set_active_storage_url_options
    # For Rails 7.1+, this is the supported way
    ActiveStorage::Current.url_options = { host: request.base_url }
    # Extra compatibility if any old code still checks .host
    ActiveStorage::Current.host = request.base_url if ActiveStorage::Current.respond_to?(:host=)
  end
end
