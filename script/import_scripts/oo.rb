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

    @htmlentities = HTMLEntities.new

    puts "loading post mappings..."
    @post_number_map = {}
    Post.pluck(:id, :post_number).each do |post_id, post_number|
      @post_number_map[post_id] = post_number
    end

    @client = TinyTds::Client.new(
      username: SQLSERVER_USER,
      password: SQLSERVER_PW,
      host: SQLSERVER_HOST,
      port: SQLSERVER_PORT,
      database: SQLSERVER_DB
    )
  end

  def created_post(post)
    @post_number_map[post.id] = post.post_number
    super
  end

  def execute
    import_groups
    import_users
    import_categories
    import_topics
    import_posts
  end

  def import_groups
    puts "", "importing groups..."

    sql = <<-SQL
        SELECT RoleID, Name, Description
          FROM forums_Roles
         WHERE RoleID > 0
    SQL

    groups = sql_query(sql).to_a

    create_groups(groups) do |g|
      {
        id: g["RoleID"],
        name: g["Name"]
      }
    end
  end

  def import_users
    puts "", "importing users..."

    total_users = sql_query("SELECT COUNT(*) count FROM forums_Users").first["count"]

    batches(BATCH_SIZE) do |offset|
      sql = <<-SQL
        SELECT UserID, Email, DirectedId, DisplayUserName
          FROM forums_Users
      ORDER BY UserID
        OFFSET #{offset} ROWS
        FETCH NEXT #{BATCH_SIZE} ROWS ONLY
      SQL

      users = sql_query(sql).to_a

      break if users.empty?

      create_users(users, total: total_users, offset: offset) do |u|
        {
          id: u["UserID"],
          username: u["DisplayUserName"],
          email: ((u["Email"] || '').downcase.presence || "fakeemail#{u["UserID"]}@fakeemail.com").gsub(/[\s\/]/, ''),
          custom_fields: {
            directed_id: u["DirectedId"]
          },
          post_create_action: proc do |user|
            result = sql_query("SELECT RoleID FROM forums_UsersInRoles WHERE UserID = #{u["UserID"]}").to_a
            GroupUser.transaction do
              result.each do |row|
                (group_id = group_id_from_imported_group_id(row["RoleID"])) && GroupUser.find_or_create_by(user: user, group_id: group_id)
              end
            end
          end
        }
      end
    end
  end

  def import_categories
    puts "", "importing categories..."

    sql = <<-SQL
        SELECT ForumID, SiteID, Name, Description, DateCreated, SortOrder
          FROM forums_Forums
        WHERE ForumID > 1
    SQL

    categories = sql_query(sql).to_a

    create_categories(categories) do |c|
      name = c["Name"]
      name = "#{name} ##{c["SiteID"]}" if ["side deals", "Woot Plus", "Woots"].include?(name)

      {
        id: c["ForumID"],
        name: name,
        description: c["Description"].presence,
        position: c["SortOrder"],
        post_create_action: proc do |category|
          Permalink.find_or_create_by(url: "forums/viewforum.aspx?forumid=#{c["ForumID"]}", category_id: category.id)
        end
      }
    end
  end

  def import_topics
    puts "", "importing topics..."

    total_topics = sql_query("
      SELECT COUNT(*) count FROM forums_Threads
      WHERE ThreadID IN (SELECT ThreadID FROM forums_Posts)
    ").first["count"]

    batches(BATCH_SIZE) do |offset|
      sql = <<-SQL
        SELECT T.ThreadID, T.ForumID, T.UserID, T.ThreadDate, T.TotalViews, T.IsLocked,
               P.Subject, P.Body
          FROM forums_Threads AS T
          INNER JOIN forums_Posts AS P ON T.ThreadID = P.ThreadID AND P.PostLevel = 1
      ORDER BY T.ThreadID
        OFFSET #{offset} ROWS
        FETCH NEXT #{BATCH_SIZE} ROWS ONLY
      SQL

      topics = sql_query(sql).to_a

      break if topics.empty?

      create_posts(topics, total: total_topics, offset: offset) do |t|
        category_id = nil
        category_id = Category.find_by(name: "Staff")&.id if t['ForumID'] == 1
        category_id ||= category_id_from_imported_category_id(t['ForumID'])

        {
          id: "#{t['ThreadID']}",
          user_id: user_id_from_imported_user_id(t["UserID"]) || find_user_by_import_id(t["UserID"])&.id || -1,
          title: @htmlentities.decode(t['Subject']).strip[0...255],
          category: category_id,
          views: t['TotalViews'],
          raw: t["Body"].gsub("[br]", "\n"),
          created_at: t["ThreadDate"],
          import_mode: true
        }
      end
    end
  end

  def import_posts
    puts "", "importing posts..."

    total_posts = sql_query("
      SELECT COUNT(*) count FROM forums_Posts WHERE PostLevel != 1
    ").first["count"]

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

      create_posts(posts, total: total_posts, offset: offset) do |p|
        next unless topic = topic_lookup_from_imported_post_id(p["ThreadID"])

        new_post = {
          id: p['PostID'],
          user_id: user_id_from_imported_user_id(p["UserID"]) || find_user_by_import_id(p["UserID"])&.id || -1,
          topic_id: topic[:topic_id],
          raw: p["Body"].gsub("[br]", "\n"),
          created_at: p["PostDate"],
          import_mode: true
        }

        reply_to_post_id = post_id_from_imported_post_id(p["ParentID"])
        if reply_to_post_id
          reply_to_post_number = @post_number_map[reply_to_post_id]
          if reply_to_post_number && reply_to_post_number > 1
            new_post[:reply_to_post_number] = reply_to_post_number
          end
        end

        new_post
      end
    end
  end

  def sql_query(sql)
    @client.execute(sql)
  end
end

if __FILE__ == $0
  ImportScripts::Oo.new.perform
end
