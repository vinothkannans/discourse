# Prereq:
#
# brew install FreeTDS
# gem 'tiny_tds'

require 'tiny_tds'
require_relative "base"

# Before running this script, paste these lines into your shell,
# then use arrow keys to edit the values
=begin
export SQLSERVER_HOST="localhost"
export SQLSERVER_PORT="1401"
export SQLSERVER_USER="sa"
export SQLSERVER_DB="PeerNetwork"
export SQLSERVER_PW="<YourStrong!Passw0rd>"
=end

class BulkImport::Oot < BulkImport::Base

  BATCH_SIZE = 1000

  SQLSERVER_HOST ||= ENV['SQLSERVER_HOST'] || "localhost"
  SQLSERVER_PORT ||= ENV['SQLSERVER_PORT'] || "1401"
  SQLSERVER_USER ||= ENV['SQLSERVER_USER'] || "sa"
  SQLSERVER_DB ||= ENV['SQLSERVER_DB'] || "PeerNetwork"
  SQLSERVER_PW ||= ENV['SQLSERVER_PW'] || "<YourStrong!Passw0rd>"

  def initialize
    super

    @htmlentities = HTMLEntities.new

    @client = TinyTds::Client.new(
      username: SQLSERVER_USER,
      password: SQLSERVER_PW,
      host: SQLSERVER_HOST,
      port: SQLSERVER_PORT,
      database: SQLSERVER_DB,
      timeout: 30
    )
  end

  def execute
    SiteSetting.download_remote_images_to_local = false
    SiteSetting.login_required = true
    SiteSetting.disable_emails = "non-staff"
    @thread_id_map = {}

    map_topics
    import_posts
  end

  def map_topics
    puts "", "mapping topics..."

    batches(BATCH_SIZE) do |offset|
      sql = <<-SQL
        SELECT T.ThreadID, P.PostID
          FROM forums_Threads AS T
          INNER JOIN forums_Posts AS P ON T.ThreadID = P.ThreadID AND P.PostLevel = 1
      ORDER BY T.ThreadID
        OFFSET #{offset} ROWS
        FETCH NEXT #{BATCH_SIZE} ROWS ONLY
      SQL

      topics = sql_query(sql).to_a

      break if topics.empty?

      topics.each do |t|
        @thread_id_map[t["ThreadID"]] = t["PostID"]
      end

      puts "", offset
    end
  end

  def import_posts
    puts "", "Importing posts..."

    batches(BATCH_SIZE) do |offset|
      sql = <<-SQL
        SELECT PostID, ThreadID, ParentID, UserID, PostDate, Body
          FROM forums_Posts
        WHERE PostLevel != 1
      ORDER BY PostID
        OFFSET #{offset} ROWS
        FETCH NEXT #{BATCH_SIZE} ROWS ONLY
      SQL

      posts = sql_query(sql).to_a

      break if posts.empty?

      create_posts(posts) do |p|
        next unless topic_id = topic_id_from_imported_id(@thread_id_map[p["ThreadID"]])
        next if p['Body'].blank?

        reply_to_post_number = p["ParentID"].present? ? post_number_from_imported_id(p["ParentID"]) : nil

        {
          imported_id: p['PostID'],
          topic_id: topic_id,
          reply_to_post_number: reply_to_post_number,
          user_id: user_id_from_imported_id(p["UserID"]),
          created_at: p["PostDate"],
          raw: format_raw(p)
        }
      end

      puts "", offset
    end
  end

  def format_raw(post)
    raw = post["Body"].gsub("[br]", "\n")

    while data = raw.match(/\[quote postid="(\d+)" user="(.+)"\]/) do
      topic_id = topic_id_from_imported_post_id(data[1]) || ""
      post_number = post_number_from_imported_id(data[1]) || ""
      username = data[2] || ""
      tag = "[quote=\"#{username}, post:#{post_number}, topic:#{topic_id}\"]"
      raw.sub!(data[0], tag)
    end

    raw
  end

  def sql_query(sql)
    @client.execute(sql)
  end

  def batches(batch_size = 1000)
    offset = 0
    loop do
      yield offset
      offset += batch_size
    end
  end
end

if __FILE__ == $0
  BulkImport::Oot.new.run
end
