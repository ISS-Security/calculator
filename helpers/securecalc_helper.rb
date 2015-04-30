module SecureCalcHelper
  def random_simple
    max = nil
    seed = nil
    request_json = request.body.read
    begin
      unless request_json.empty?
        req = JSON.parse(request_json)
        max = req['max']
        seed = req['seed']
      end

      req_params = { max: max, seed: seed }
      op = Operation.new(operation: 'random_simple',
                         parameters: req_params.to_json)
      op.save

      seed ||= Random.new_seed
      randomizer = Random.new(seed)
      result = max ? randomizer.rand(max) : randomizer.rand

      { random: result,
        seed: seed,
        notes: 'Simple PRNG not for secure use'
      }
    rescue
      halt 400, 'Check parameters max and seed are numbers (integer or float)'
    end
  end
end
