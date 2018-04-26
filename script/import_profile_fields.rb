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

  def print_status(current, success, start_time = nil)
    if start_time.present?
      elapsed_seconds = Time.now - start_time
      elements_per_minute = '[%.0f items/min]  ' % [current / elapsed_seconds.to_f * 60]
    else
      elements_per_minute = ''
    end

    print "\r%9d / %9d %s" % [success, current, elements_per_minute]
  end

  def perform
    Rails.logger.level = 3
    puts "Started..."
    #save_ids
    migrate
    puts "...Finished"
  end

  def save_ids
    ids = {}
    UserCustomField.where(name: "import_id").pluck(:user_id, :value).each do |field|
      ids[field[1]] = field[0]
    end
    PluginStore.set("import", "ids", ids);
  end

  def migrate
    @ids = PluginStore.get("import", "ids")

    migrate_field("jobtitle", 1)
    migrate_field("company", 2)
    migrate_field("industry", 3)
    migrate_location
  end

  def migrate_field(name, i)
    current = 0
    results = mysql_query("SELECT user_id, nvalue FROM user_profile WHERE param = 'profile.#{name}'")
    results.each do |row|
      lithium_id = row["user_id"]
      user_id = @ids[lithium_id.to_s]
      next if user_id.blank?
      UserCustomField.create(user_id: user_id, name: "user_field_#{i}", value: row["nvalue"])
      print_status(current += 1, i)
    end
  end

  def migrate_location
    current = 0
    results = mysql_query("SELECT user_id, nvalue FROM user_profile WHERE param = 'profile.location'")
    results.each do |row|
      lithium_id = row["user_id"]
      user_id = @ids[lithium_id.to_s]
      next if user_id.blank?
      profile = UserProfile.find_by(user_id: user_id)
      next if profile.blank?
      profile.update_attribute(:location, row["nvalue"])
      print_status(current += 1, 4)
    end
  end

end

ImportProfileFields.new.perform
