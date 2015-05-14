require 'sinatra'
require 'json'
require 'config_env'
require_relative 'model/operation'
require_relative 'model/user'
require_relative 'helpers/securecalc_helper'

# Security Calculator Web Service
class SecurityCalculator < Sinatra::Base
  include SecureCalcHelper
  enable :logging

  configure :development, :test do
    ConfigEnv.path_to_config("#{__dir__}/config/config_env.rb")
  end

  configure :development do
    require 'hirb'
    Hirb.enable
  end

  configure do
    use Rack::Session::Cookie, secret: ENV['MSG_KEY']
    # use Rack::Session::Pool   # do not use `shotgun` with pooled sessions
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
    haml :register
  end

  post '/register' do
    logger.info('REGISTER')
    username = params[:username]
    email = params[:email]
    password = params[:password]
    password_confirm = params[:password_confirm]
    begin
      if password == password_confirm
        new_user = User.new(username: username, email: email)
        new_user.password = password
        new_user.save! ? login_user(new_user) : fail('Could not create new user')
      else
        fail 'Passwords do not match'
      end
    rescue => e
      logger.error(e)
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
    user ? login_user(user) : redirect('/login')
  end

  get '/logout' do
    session[:auth_token] = nil
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
