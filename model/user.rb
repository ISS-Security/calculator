require 'sinatra/activerecord'
require 'protected_attributes'
require_relative '../environments'
require 'rbnacl/libsodium'
require 'base64'

class User < ActiveRecord::Base
  validates :username, presence: true, uniqueness: true
  validates :email, presence: true, format: /@/
  validates :hashed_password, presence: true

  attr_protected :salt, :hashed_password

  def password=(new_password)
    salt = RbNaCl::Random.random_bytes(RbNaCl::PasswordHash::SCrypt::SALTBYTES)
    opslimit = 2**20
    memlimit = 2**24
    digest_size = 64

    digest = RbNaCl::PasswordHash.scrypt(new_password, salt, opslimit,
                                         memlimit, digest_size)
    self.salt = Base64.urlsafe_encode64(salt)
    self.hashed_password = Base64.urlsafe_encode64(digest )
  end
end
