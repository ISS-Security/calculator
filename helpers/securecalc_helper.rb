require 'rbnacl/libsodium'
require 'jwt'
require 'pony'

module SecureCalcHelper
  class Registration
    attr_accessor :username, :email, :password

    def initialize(username, email, password)
      @username = username
      @email = email
      @password = password
    end

    def complete?
      (username && username.length > 0) &&
      (email && email.length > 0) &&
      (password && password.length > 0)
    end
  end

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
    payload = {username: registration.username, email: registration.email,
               password: registration.password}
    token = JWT.encode payload, ENV['MSG_KEY'], 'HS256'
    verification = Base64.urlsafe_encode64(encrypt_message(token).to_s)
    Pony.mail(to: registration.email,
              subject: "Your SecureCalculator Account is Ready",
              html_body: registration_email(verification))
    flash[:notice] = "A verification link has been sent to you. Please check your email!"
    redirect '/'
  rescue => e
    logger.error "FAIL EMAIL: #{e}"
    flash[:error] = "Could not send registration verification: check email address"
    redirect '/register'
  end

  def registration_email(token)
    verification_url = "#{request.base_url}/register?token=#{token}"
    "<H1>SecureCalculator Registration Received<H1>" \
    "<p>Please <a href=\"#{verification_url}\">click here</a> to validate " \
    "your email and activate your account</p>"
  end

  def encrypt_message(message)
    key = Base64.urlsafe_decode64(ENV['MSG_KEY'])
    secret_box = RbNaCl::SecretBox.new(key)
    nonce = RbNaCl::Random.random_bytes(secret_box.nonce_bytes)

    key_s = Base64.urlsafe_encode64(key)
    nonce_s = Base64.urlsafe_encode64(nonce)
    message_enc = secret_box.encrypt(nonce, message.to_json)
    message_enc_s = Base64.urlsafe_encode64(message_enc)
    {'message'=>message_enc_s, 'nonce'=>nonce_s}
  end

  def register_account(registration)
    new_user = User.new(username: username, email: email)
    new_user.password = password
    new_user.save! ? login_user(new_user) : fail('Could not create new user')
  rescue => e
    logger.error(e)
    flash[:error] = "Could not create new user in database: please check input"
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
