module SecureCalcHelper
  def random_simple(max=nil, seed=nil)
    req_params = { max: max, seed: seed }
    op = Operation.new(operation: 'random_simple',
                       parameters: req_params.to_json)
    op.save

    seed ||= Random.new_seed
    randomizer = Random.new(seed)
    result = max ? randomizer.rand(max) : randomizer.rand

    { random: result, seed: seed,
      notes: 'Simple PRNG not for secure use' }
  end

  def login_user(user)
    session[:user_id] = user.id
    redirect '/'
  end
end
