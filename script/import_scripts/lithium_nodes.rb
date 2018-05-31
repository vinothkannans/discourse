require 'mysql2'
require File.expand_path(File.dirname(__FILE__) + "/base.rb")

class ImportScripts::LithiumNodes < ImportScripts::Base
  # CHANGE THESE BEFORE RUNNING THE IMPORTER
  DATABASE = "gartner"
  PASSWORD = "vinkas"

  def initialize
    super

    @old_username_to_new_usernames = {}

    @htmlentities = HTMLEntities.new

    @client = Mysql2::Client.new(
      host: "localhost",
      username: "root",
      password: PASSWORD,
      database: DATABASE
    )
  end

  def execute
    import_categories
  end

  def import_categories
    puts "", "importing categories..."
    Category.all.each do |category|
      import_id = category.custom_fields["import_id"]
      next unless import_id.present?

      result = mysql_query <<-SQL
        SELECT display_id FROM nodes WHERE node_id = #{import_id}
      SQL

      next unless result.present?

      display_id = result.first["display_id"]
      CategoryCustomField.create!(category_id: category.id, name: "import_display_id", value: display_id)

      puts "."
    end
    puts "", "finished."
  end

  def mysql_query(sql)
    @client.query(sql, cache_rows: true)
  end

end

ImportScripts::LithiumNodes.new.perform
