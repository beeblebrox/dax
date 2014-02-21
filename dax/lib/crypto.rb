require 'openssl'
require 'digest/sha2'

module Crypto

  def self.encrypt(key, message)
    @sha256 = Digest::SHA2.new(256) if not @sha256
    aes = OpenSSL::Cipher.new("AES-256-CFB")
    key = @sha256.digest(key)
    
    aes.encrypt
    aes.key = key
    iv = aes.random_iv
    encrypted_data = aes.update(message) + aes.final
    encrypted_data = iv + encrypted_data
  end

  def self.decrypt(key, cipher)
    @sha256 = Digest::SHA2.new(256) if not @sha256
    aes = OpenSSL::Cipher.new("AES-256-CFB")
    iv =  cipher.byteslice(0..15)
    key = @sha256.digest(key)
    
    aes.decrypt
    aes.key = key
    aes.iv = iv
    aes.update(cipher[16, cipher.bytesize - 16]) + aes.final
  end

end
