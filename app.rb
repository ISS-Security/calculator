require 'sinatra'
require 'json'
require 'config_env'
require_relative 'model/operation'
require_relative 'helpers/securecalc_helper'

# Security Calculator Web Service
class SecurityCalculator < Sinatra::Base
  include SecureCalcHelper

  configure :development, :test do
    ConfigEnv.path_to_config("#{__dir__}/config/config_env.rb")
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
