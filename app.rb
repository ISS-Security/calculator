require 'sinatra'
require 'rack-flash'
require 'json'

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

  configure do
    use Rack::Session::Cookie, secret: ENV['MSG_KEY']
    # use Rack::Session::Pool   # do not use `shotgun` with pooled sessions
    use Rack::Flash, :sweep => true
  end

  before do
    @current_user = find_user_by_token(session[:auth_token])
  end

  get '/api/v1/?' do
    'Services offered include<br>' \
    ' GET /api/v1/hash_murmur?text=[your text]<br>' \
    ' POST /api/v1/random_simple (numeric parameters: max, body)'
  end

  get '/api/v1/hash_murmur' do
    content_type :json
    plaintext = params[:text]
    halt 400 unless plaintext

    op = Operation.new(operation: 'hash_murmur',
                       parameters: { text: plaintext }.to_json)
    op.save

    { hash: plaintext.hash,
      notes: 'Non-cryptographic hash not for secure use'
    }.to_json
  end

  post '/api/v1/random_simple' do
    content_type :json
    max = seed = nil
    request_json = request.body.read
    unless request_json.empty?
      req = JSON.parse(request_json)
      max = req['max']
      seed = req['seed']
    end

    random_simple(max, seed).to_json
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
      @random_results = random_simple(max, seed)
      puts @random_results.inspect
      haml :random_simple
    rescue => e
      puts e
      halt 400, 'Check parameters max and seed are numbers (integer or float)'
    end
  end
end
