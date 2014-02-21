require 'spec_helper.rb'

describe Crypto do
  
  it 'round robins' do
    secret = "monkey island."
    cipher = Crypto.encrypt("secretkey", secret)
    expect(cipher).not_to eq secret
    pandora = Crypto.decrypt("secretkey", cipher)
    expect(pandora).to eq secret
  end
  
end