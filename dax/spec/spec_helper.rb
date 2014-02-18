require 'dax'
require 'rspec/expectations'

RSpec.configure do |c|
  # declare an exclusion filter
  c.filter_run_excluding :broken => true
end

RSpec::Matchers.define :set_contain_file_named do |name|
  match do |set|
     true if set.to_a.index do |fileHash|
      fileHash[:name] == name
    end
  end
end
