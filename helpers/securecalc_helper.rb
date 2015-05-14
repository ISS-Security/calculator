require 'rbnacl/libsodium'
require 'jwt'
require 'pony'

module SecureCalcHelper
  Registration = Struct.new(:username, :email, :password)

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

  def email_registration_verification(registration)
    payload = encrypt_message(registration)
    token = JWT.encode payload, ENV['MSG_KEY'], 'HS256'
    Pony.mail(subject: "Your SecureCalculator Account is Ready",
              to: registration.email, html_body: registration_email(token))
  rescue => e
    fail "Registration verification could not be sent"
    logger.error e
  end

  def registration_email(token)
    verification_url = "#{request.base_url}/register/#{token}"
    "<H1>SecureCalculator Registration Received<H1>" \
    "<p>Please <a href=\"#{verification_url}\">click here</a> to validate " \
    "your email and activate your account</p>"
  end

  def encrypt_message(registration)
    key = Base64.urlsafe_decode64(ENV['MSG_KEY'])
    secret_box = RbNaCl::SecretBox.new(key)
    nonce = RbNaCl::Random.random_bytes(secret_box.nonce_bytes)

    key_s = Base64.urlsafe_encode64(key)
    nonce_s = Base64.urlsafe_encode64(nonce)
    registration_enc = secret_box.encrypt(nonce, registration.to_json)
    registration_enc_s = Base64.urlsafe_encode64(registration_enc)
    {'body'=>registration_enc_s, 'nonce'=>nonce_s}
  end

  def register_account(registration)
    new_user = User.new(username: username, email: email)
    new_user.password = password
    new_user.save! ? login_user(new_user) : fail('Could not create new user')
  rescue => e
    logger.error(e)
    redirect '/register'
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
    User.find_by_id(payload["user_id"])
  end
end
