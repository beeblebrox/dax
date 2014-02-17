require 'spec_helper'
require 'pathname'

describe DB do

  before do
    @with_set1 = Pathname.new "tmp_set1"
    @with_set2 = Pathname.new "tmp_set2"
    common_set = [ :name => "a", :data => "aaaaaaaaa" ] +
                 [ :name => "c", :data => "ccccccccc" ]
    @set_1 =     [ :name => "b", :data => "bbbbbbbbb" ] +
                 [ :name => "changed", :data => "first"]
                common_set
                 [ :name => "changed", :data => "first" ]
    @set_2 =      [ :name => "d", :data => "dddddddd" ] +
                 [ :name => "changed", :data => "second" ] +
                 common_set
    @with_db = Pathname.new 'db_tmp'

    `mkdir -p #{@with_set1.to_s}`
    `mkdir -p #{@with_set2.to_s}`
    `mkdir -p #{@with_db.to_s}`

    @set_1.each do |finfo|
      File.open(@with_set1 + finfo[:name], "w") do |file|
        file.puts finfo[:data]
      end
    end
    
    @set_2.each do |finfo|
      File.open(@with_set2 + finfo[:name], "w") do |file|
        file.puts finfo[:data]
      end
    end
  end

  after do
    `rm -rf #{@with_set1.to_s}`
    `rm -rf #{@with_set2.to_s}`
    `rm -rf #{@with_db.to_s}`
  end
  
  it "#init create DB" do
    dbFile = (@with_db + 'db').to_s
    expect(File).not_to exist(dbFile)
    db = DB.new :db_location => dbFile, :files_location => @with_set1.to_s
    db.init
    expect(File).to exist(dbFile)
  end
  
  it "detects differences" do
    dbFile = (@with_db + 'db').to_s
    db = DB.new :db_location => dbFile, :files_location => @with_set1.to_s
    db.init
    db.refresh
  
    dbFile2 = (@with_db + 'db2').to_s
    db2 = DB.new :db_location => dbFile2, :files_location => @with_set2.to_s
    db2.init
    db2.refresh
  
    p db.additional_compared_to db2
  end
end