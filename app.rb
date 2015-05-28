require 'sinatra'
require 'rack/ssl-enforcer'
require 'rack-flash'
require 'json'
require 'httparty'

configure :development, :test do
  require 'config_env'
  ConfigEnv.path_to_config("#{__dir__}/config/config_env.rb")
end

require_relative 'model/operation'
require_relative 'model/user'
require_relative 'helpers/securecalc_helper'

# Security Calculator Web Service
class SecurityCalculator < Sinatra::Base
  include SecureCalcHelper
  enable :logging

  configure :development do
    require 'hirb'
    Hirb.enable
  end

  configure :production do
    use Rack::SslEnforcer
    set :session_secret, ENV['MSG_KEY']
  end

  configure do
    use Rack::Session::Cookie, secret: settings.session_secret
    # use Rack::Session::Pool   # do not use `shotgun` with pooled sessions
    use Rack::Flash, :sweep => true
  end

  API_URL = 'https://securecalc-api.herokuapp.com/api/v1/'

  before do
    @current_user = find_user_by_token(session[:auth_token])
  end

  get '/' do
    haml :index
  end

  get '/register' do
    if token = params[:token]
      begin
        create_user_with_encrypted_token(token)
        flash[:notice] = "Welcome! Your account has been successfully created."
      rescue
        flash[:error] = "Your account could not be created. Your link is either expired or invalid."
      end
      redirect '/'
    else
      haml(:register)
    end
  end

  post '/register' do
    registration = Registration.new(params)

    if (registration.complete?) && (params[:password] == params[:password_confirm])
      begin
        email_registration_verification(registration)
        flash[:notice] = "A verification link has been sent to you. Please check your email!"
        redirect '/'
      rescue => e
        logger.error "FAIL EMAIL: #{e}"
        flash[:error] = "Could not send registration verification: check email address"
        redirect '/register'
      end
    else
      flash[:error] = "Please fill in all the fields and make sure passwords match"
      redirect '/register'
    end
  end

  get '/login' do
    haml :login
  end

  post '/login' do
    username = params[:username]
    password = params[:password]
    user = User.authenticate!(username, password)
    if user
      login_user(user)
      redirect '/'
    else
      flash[:error] = "We could not find your account with those credentials"
      redirect '/login'
    end
  end

  get '/logout' do
    session[:auth_token] = nil
    flash[:notice] = "You have logged out"
    redirect '/'
  end

  get '/random_simple' do
    haml :random_simple
  end

  post '/random_simple' do
    begin
      max = params[:max].to_i unless params[:max].empty?
      seed = params[:seed].to_i unless params[:seed].empty?
      @random_results = HTTParty.post API_URL+'random_simple',
                             body: {max: max, seed: seed}.to_json
      # @random_results = random_simple(max, seed)
      puts @random_results.inspect
      haml :random_simple
    rescue => e
      puts e
      halt 400, 'Check parameters max and seed are numbers (integer or float)'
    end
  end
end
