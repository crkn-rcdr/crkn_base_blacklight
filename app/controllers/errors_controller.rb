# frozen_string_literal: true

class ErrorsController < ApplicationController
  include Blacklight::Configurable
  copy_blacklight_config_from(CatalogController)

  layout 'blacklight'

  def not_found
    respond_to do |format|
      format.html { render status: :not_found }
      format.all  { head :not_found }
    end
  end

  def internal_server_error
    respond_to do |format|
      format.html { render status: :internal_server_error }
      format.all  { head :internal_server_error }
    end
  end
end
