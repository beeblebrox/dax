require 'dax'
require 'rspec/expectations'
require 'json'

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


RSpec::Matchers.define :have_json_result do |value|
  match do |json|
    result = JSON.parse(json, :symbolize_names => true)
    false unless result.has_key? :result
    result[:result] == value
  end
end
