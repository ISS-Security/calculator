require 'jwt'

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
    payload = {user_id: user.id}
    token = JWT.encode payload, ENV['MSG_KEY'], 'HS256'
    session[:auth_token] = token
    redirect '/'
  end

  def find_user_by_token(token)
    return nil unless token
    decoded_token = JWT.decode token, ENV['MSG_KEY'], true
    payload = decoded_token.first
    logger.info "PAYLOAD: #{payload}"
    User.find_by_id(payload["user_id"])
  end
end
