# Prereq:
#
# brew install FreeTDS
# gem 'tiny_tds'

require 'tiny_tds'
require File.expand_path(File.dirname(__FILE__) + "/base.rb")

# Before running this script, paste these lines into your shell,
# then use arrow keys to edit the values
=begin
export SQLSERVER_HOST="localhost"
export SQLSERVER_PORT="1401"
export SQLSERVER_USER="sa"
export SQLSERVER_DB="PeerNetwork"
export SQLSERVER_PW="<YourStrong!Passw0rd>"
=end

class ImportScripts::Oo < ImportScripts::Base

  BATCH_SIZE = 1000

  SQLSERVER_HOST ||= ENV['SQLSERVER_HOST'] || "localhost"
  SQLSERVER_PORT ||= ENV['SQLSERVER_PORT'] || "1401"
  SQLSERVER_USER ||= ENV['SQLSERVER_USER'] || "sa"
  SQLSERVER_DB ||= ENV['SQLSERVER_DB'] || "PeerNetwork"
  SQLSERVER_PW ||= ENV['SQLSERVER_PW'] || "<YourStrong!Passw0rd>"

  def initialize
    super

    @client = TinyTds::Client.new(
      username: SQLSERVER_USER,
      password: SQLSERVER_PW,
      host: SQLSERVER_HOST,
      port: SQLSERVER_PORT,
      database: SQLSERVER_DB
    )
  end

  def execute
    import_users
    import_categories
    import_topics_and_posts
  end

  def import_users
    puts "", "importing users..."
  end

  def import_categories
    puts "", "importing users..."
  end

  def import_topics_and_posts
    puts "", "importing users..."
  end
end

if __FILE__ == $0
  ImportScripts::Oo.new.perform
end

