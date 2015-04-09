require 'sinatra'

# Security Calculator Web Service
class SecurityCalculator < Sinatra::Base
  get '/' do
    'SecurityCalculator is up and running; API available at /api/v1/'
  end

  get '/api/v1' do
    'Services offered include<br>' \
    ' GET /api/v1/hash_murmur?text=[your text]<br>' \
    ' POST /api/v1/random_simple (numeric parameters: max, body)'
  end

  get '/api/v1/hash_murmur' do
    plaintext = params[:text]
    halt 400 unless plaintext

    { hash: plaintext.hash,
      notes: 'Non-cryptographic hash not for secure use'
    }.to_json
  end

  post '/api/v1/random_simple' do
    max = nil
    seed = nil
    request_json = request.body.read
    begin
      unless request_json.empty?
        req = JSON.parse(request_json)
        max = req['max']
        seed = req['seed']
      end

      seed ||= Random.new_seed
      randomizer = Random.new(seed)
      result = max ? randomizer.rand(max) : randomizer.rand

      { random: result,
        seed: seed,
        notes: 'Simple PRNG not for secure use'
      }.to_json
    rescue
      halt 400, 'Check parameters max and seed are numbers (integer or float)'
    end
  end
end
