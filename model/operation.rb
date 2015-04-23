require 'sinatra/activerecord'
require_relative '../environments'
require 'rbnacl/libsodium'

class Operation < ActiveRecord::Base
  def key
    ENV['DB_KEY'].dup.force_encoding Encoding::BINARY
  end

  def parameters=(params_str)
    secret_box = RbNaCl::SecretBox.new(key)
    self.nonce = RbNaCl::Random.random_bytes(secret_box.nonce_bytes)
    self.encrypted_parameters = secret_box.encrypt(self.nonce, params_str)
  end

  def parameters
    secret_box = RbNaCl::SecretBox.new(key)
    secret_box.decrypt(self.nonce, self.encrypted_parameters)
  end
end
