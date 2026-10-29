class ApplicationController < ActionController::Base
  # Adds a few additional behaviors into the application controller
  include Blacklight::Controller
  layout :determine_layout if respond_to? :layout

  before_action :set_locale
  after_action :set_content_language

  rescue_from Blacklight::Exceptions::RecordNotFound, with: :render_not_found

  def render_not_found
    respond_to do |format|
      format.html { render 'errors/not_found', status: :not_found, layout: 'blacklight' }
      format.all  { head :not_found }
    end
  end

  private

  def set_locale
    I18n.locale = params[:lang] ||
                  session[:locale] ||
                  extract_locale_from_header ||
                  I18n.default_locale

    session[:locale] = I18n.locale
    cookies[:locale] = {
      value: I18n.locale.to_s,
      expires: 1.year.from_now,
      path: '/',
      same_site: :lax,
      httponly: false
    }
  end

  def extract_locale_from_header
    return if request.env['HTTP_ACCEPT_LANGUAGE'].blank?

    # Get the first language from the header, like 'fr', 'en', etc.
    lang = request.env['HTTP_ACCEPT_LANGUAGE'].scan(/^[a-z]{2}/).first
    lang if I18n.available_locales.map(&:to_s).include?(lang)
  end

  def set_content_language
    response.set_header('Content-Language', I18n.locale.to_s)
    response.set_header('Access-Control-Expose-Headers', 'Content-Language')

  end

  def default_url_options
    { lang: I18n.locale }
  end
end
