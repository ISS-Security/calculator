require 'sinatra'
require 'rack/ssl-enforcer'
require 'rack-flash'
require 'json'
require 'httparty'
require 'hirb'
require 'dalli'
require 'active_support'
require 'active_support/core_ext'

configure :development, :test do
  require 'config_env'
  ConfigEnv.path_to_config("#{__dir__}/config/config_env.rb")
end

require_relative 'model/user'
require_relative 'helpers/securecalc_helper'

# Security Calculator Web Service
class SecurityCalculator < Sinatra::Base
  include SecureCalcHelper
  enable :logging

  configure :production do
    use Rack::SslEnforcer
    set :session_secret, ENV['MSG_KEY']
  end

  configure do
    use Rack::Session::Cookie, secret: ENV['MSG_KEY']
    # use Rack::Session::Pool   # do not use `shotgun` with pooled sessions
    use Rack::Flash, :sweep => true
    Hirb.enable

    set :ops_cache, Dalli::Client.new((ENV["MEMCACHIER_SERVERS"] || "").split(","),
      {:username => ENV["MEMCACHIER_USERNAME"],
        :password => ENV["MEMCACHIER_PASSWORD"],
        :socket_timeout => 1.5,
        :socket_failure_delay => 0.2
        })
  end

  register do
    def auth(*types)
      condition do
        if (types.include? :user) && !@current_user
          flash[:error] = "You must be logged in for that page"
          redirect "/login"
        end
      end
    end
  end

  before do
    @current_user = find_user_by_token(session[:auth_token])
  end

  get '/' do
    @op_index = if @current_user
      JSON.parse( settings.ops_cache.fetch(@current_user.id) { api_operation_index.to_json } )
    else
      nil
    end
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

  get '/user/:username', :auth => [:user] do
    username = params[:username]
    unless username == @current_user.username
      flash[:error] = "You may only look at your own profile"
      redirect '/'
    end

    haml :profile
  end

  get '/gh_callback' do
    gh = HTTParty.post('https://github.com/login/oauth/access_token',
                       body: {client_id: ENV['GH_CLIENT_ID'],
                              client_secret: ENV['GH_CLIENT_SECRET'],
                              code: params['code']},
                       headers: {'Accept' => 'application/json'})

    gh_user = HTTParty.get(
              'https://api.github.com/user',
              body: {params: {access_token: gh['access_token']}},
              headers: {'User-Agent' => ENV['GH_CLIENT_NAME'],
                        'Authorization' => "token #{gh['access_token']}"})

    username = gh_user['login']
    email = gh_user['email']
    if user = find_user_by_username(username)
      login_user(user)
    else
      create_gh_user(username, email, gh['access_token'])
    end

    redirect '/'
  end

  get '/random_simple', :auth => [:user] do
    haml :random_simple
  end

  post '/random_simple' do
    begin
      max = params[:max].to_i unless params[:max].empty?
      seed = params[:seed].to_i unless params[:seed].empty?
      @random_results = api_random_simple(max, seed)
      puts "RANDOM_RESULTS: #{@random_results}"
      haml :random_simple
    rescue => e
      puts e
      halt 400, 'Check parameters max and seed are numbers (integer or float)'
    end
  end
end
