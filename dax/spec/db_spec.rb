require 'spec_helper'
require 'pathname'

describe "db#first_file_with_checksum" do

  before do
    @file_set = Pathname.new "tmp_set1"
    @common_set = [ :name => "a", :data => "aaaaaaaaa" ] +
                 [ :name => "a2", :data => "aaaaaaaaa" ] +
                 [ :name => "c", :data => "ccccccccc" ]
    @with_db = Pathname.new 'db_tmp'

    `mkdir -p #{@file_set.to_s}`
    `mkdir -p #{@with_db.to_s}`

    @common_set.each do |finfo|
      File.open(@file_set + finfo[:name], "w") do |file|
        file.write finfo[:data]
      end
    end
    
  end

  after do
    `rm -rf #{@file_set.to_s}`
    `rm -rf #{@with_db.to_s}`
  end
  
  it "finds first" do
  begin
    dbFile = (@with_db + 'db').to_s
    expect(File).not_to exist(dbFile)
    db = DB.new :db_location => dbFile, :files_location => @file_set.to_s
    db.refresh
    expect(File).to exist(dbFile)
    file = db.first_file_with_checksum Digest::SHA1.hexdigest "aaaaaaaaa"
    expect(file).to be
    expect(file[:name]).to eq "a"
  ensure
    db.cleanup if db
  end
  end
end

describe DB do

  before do
    @with_set1 = Pathname.new "tmp_set1"
    @with_set2 = Pathname.new "tmp_set2"
    common_set = [ :name => "a", :data => "aaaaaaaaa" ] +
                 [ :name => "c", :data => "ccccccccc" ]
    @set_1 =     [ :name => "b", :data => "bbbbbbbbb" ] +
                 [ :name => "changed", :data => "first"] +
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
  begin
    dbFile = (@with_db + 'db').to_s
    expect(File).not_to exist(dbFile)
    db = DB.new :db_location => dbFile, :files_location => @with_set1.to_s
    db.init
    expect(File).to exist(dbFile)
  ensure
    db.cleanup if db
  end
  end
  
  it "finds differences" do
  begin
    dbFile = (@with_db + 'db').to_s
    db = DB.new :db_location => dbFile, :files_location => @with_set1.to_s
    db.refresh
  
    dbFile2 = (@with_db + 'db2').to_s
    db2 = DB.new :db_location => dbFile2, :files_location => @with_set2.to_s
    db2.refresh
    result1 = db.additional_compared_to db2
    expect(result1.length).to eq 2
    expect(result1).to set_contain_file_named "b"
    expect(result1).to set_contain_file_named "changed"
  ensure 
    db.cleanup if db
    db2.cleanup if db2
  end
  end

  it "detects modifications", :broken => false do
    begin
      dbFile = (@with_db + 'db').to_s
      db = DB.new :db_location => dbFile, :files_location => @with_set1.to_s
      db.refresh
      result1 = db.files
      expect(result1.length).to eq 4
      expect(result1).to set_contain_file_named "a"
      expect(result1).to set_contain_file_named "b"
      expect(result1).to set_contain_file_named "c"
      expect(result1).to set_contain_file_named "changed"
      changedSHA = nil
      result1.each do |file|
        changedSHA = file[:sha] if file[:name] == "changed"
      end
      expect(changedSHA).to be
      
      File.open((@with_set1 + "e").to_s, "w") do |file|
        file.puts "eeeeeeee"
      end
      
      File.open((@with_set1 + "changed").to_s, "w") do |file|
        file.puts "youbetchya"
      end
      sleep 1
      changedSHATo = nil
      result2 = db.files
      result2.each do |file|
        changedSHATo = file[:sha] if file[:name] == "changed"
      end
      expect(result2).to set_contain_file_named "e"
      expect(changedSHATo).not_to eq changedSHA
    ensure
      db.cleanup if db
    end
  end
end