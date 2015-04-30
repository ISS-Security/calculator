require 'sinatra/activerecord'
require_relative '../environments'
require 'rbnacl/libsodium'
require 'base64'

class Operation < ActiveRecord::Base
  def key
    Base64.urlsafe_decode64(ENV['DB_KEY'])
  end

  def parameters=(params_str)
    secret_box = RbNaCl::SecretBox.new(key)
    nonce = RbNaCl::Random.random_bytes(secret_box.nonce_bytes)
    ciphertext = secret_box.encrypt(nonce, params_str)
    self.nonce = Base64.urlsafe_encode64(nonce)
    self.encrypted_parameters = Base64.urlsafe_encode64(ciphertext)
  end

  def parameters
    secret_box = RbNaCl::SecretBox.new(key)
    nonce = Base64.urlsafe_decode64(self.nonce)
    stored_secret = Base64.urlsafe_decode64(self.encrypted_parameters)
    secret_box.decrypt(nonce, stored_secret)
  end
end
