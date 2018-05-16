require File.expand_path("../../config/environment", __FILE__)

require 'mysql2'

class ImportProfileFields

  DATABASE = "gartner"
  PASSWORD = "vinkas"

  def mysql_query(sql)
    @client.query(sql, cache_rows: true)
  end

  def initialize
    super

    @client = Mysql2::Client.new(
      host: "localhost",
      username: "root",
      password: PASSWORD,
      database: DATABASE
    )
  end

  def perform
    Rails.logger.level = 3
    puts "Started..."
    check
    puts "...Finished"
  end

  def check
    emails = mysql_query("SELECT id, sso_id, email FROM users WHERE email LIKE '%''%'")
    emails.each do |r|
      email = r["email"]
      if email.include? "'"
        puts "#{r["id"]}, #{r["sso_id"]}, #{r["email"]}"
      else
        email = r["email"].gsub("'", "")
        user = User.find_by_email(email)
        unless user
          result = mysql_query("SELECT id, sso_id, email FROM users WHERE email = '#{email}'")
          result.each do |u|
            puts "#{u["id"]}, #{u["sso_id"]}, #{u["email"]}"
          end
        end
      end
    end
  end

end

ImportProfileFields.new.perform
