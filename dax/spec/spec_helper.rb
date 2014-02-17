require 'dax'
require 'rspec/expectations'

RSpec::Matchers.define :set_contain_file_named do |name|
  match do |set|
     true if set.to_a.index do |fileHash|
      fileHash[:name] == name
    end
  end
end
