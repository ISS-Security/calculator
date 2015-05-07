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
    digest = self.class.hash_password(salt, new_password)
    self.salt = Base64.urlsafe_encode64(salt)
    self.hashed_password = Base64.urlsafe_encode64(digest)
  end

  def self.authenticate(username, login_password)
    user = User.find_by_username(username)
    user && user.password_matches?(login_password) ? user : nil
  end

  def password_matches?(try_password)
    salt = Base64.urlsafe_decode64(self.salt)
    attempted_password = self.class.hash_password(try_password, salt)
    hashed_password == Base64.urlsafe_encode64(attempted_password)
  end

  def self.hash_password(pwd, salt)
    opslimit = 2**20
    memlimit = 2**24
    digest_size = 64
    RbNaCl::PasswordHash.scrypt(pwd, salt, opslimit, memlimit, digest_size)
  end
end
