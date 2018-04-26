require File.expand_path("../../config/environment", __FILE__)

require 'mysql2'

class ImportAvatars

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

  UPLOAD_DIR = '/home/vinkas/discourse/tmp/peerphoto'

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
    #save_sso_ids
    #migrate_sso
    migrate
    puts "...Finished"
  end

  def save_sso_ids
    sso_ids = {}
    results = mysql_query("SELECT id, sso_id FROM users")
    results.each do |row|
      sso_ids[row["id"]] = row["sso_id"]
    end
    PluginStore.set("import", "sso_ids", sso_ids);
  end

  def migrate_sso
    current = 0
    success = 0
    ids = PluginStore.get("import", "sso_ids")

    User.includes("_custom_fields").all.each do |user|
      gartner_id = ids[user.lithium_id.to_s]

      if user.custom_fields["import_sso_id"].present? || gartner_id.blank?
        print_status(current += 1, success)
        next
      end

      UserCustomField.create(user_id: user.id, name: "import_sso_id", value: gartner_id)
      print_status(current += 1, success += 1)
    end
  end

  def migrate
    current = 0
    success = 0
    files = Dir.entries(UPLOAD_DIR)

    files.each do |filename|
      next if filename.ends_with?("_actual.jpeg")

      # gartner_id = filename.sub("_actual.jpeg", "")
      gartner_id = filename.sub("_profile.jpeg", "") # if filename.ends_with?(".jpeg")

      if gartner_id.blank?
        print_status(current += 1, success)
        next
      end

      user = UserCustomField.find_by(name: "import_sso_id", value: gartner_id)&.user

      if user.blank?
        print_status(current += 1, success)
        next
      end

      if user.uploaded_avatar_id.nil?
        begin
          image = "#{UPLOAD_DIR}/#{filename}"
          File.open(image) do |file|
            upload = UploadCreator.new(file, image, type: "avatar").create_for(user.id)
            user.create_user_avatar unless user.user_avatar

            if !user.user_avatar.contains_upload?(upload.id)
              user.user_avatar.update_columns(custom_upload_id: upload.id)

              if user.uploaded_avatar_id.nil? ||
                  !user.user_avatar.contains_upload?(user.uploaded_avatar_id)
                user.update_columns(uploaded_avatar_id: upload.id)
                success += 1
              end
            end
          end
        rescue => e
          puts "Got a error on user: #{user.id} #{e}"
          raise e
        end
      else
        success += 1
      end
      
      print_status(current += 1, success)
    end
  end

end

ImportAvatars.new.perform
