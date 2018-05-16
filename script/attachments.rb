require File.expand_path("../../config/environment", __FILE__)
require File.expand_path(File.dirname(__FILE__) + "/import_scripts/base.rb")
require 'mysql2'

class Attachments < ImportScripts::Base

  DATABASE = "gartner"
  PASSWORD = "vinkas"
  ATTACHMENT_DIR = '/home/vinkas/discourse/tmp/attachments'

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
    old_extensions = SiteSetting.authorized_extensions
    old_max_att_size = SiteSetting.max_attachment_size_kb
    SiteSetting.authorized_extensions = "*"
    SiteSetting.max_attachment_size_kb = 307200
    migrate
    SiteSetting.authorized_extensions = old_extensions
    SiteSetting.max_attachment_size_kb = old_max_att_size
    puts "...Finished"
  end

  def migrate
    # Post.where("raw like '%\")  \n](/gartner%'").each do |post|
    #   raw = post.raw
    #   raw.gsub!(/\"\)  \n\]\(\/gartner/, '")](/gartner')

    #   post.raw = raw
    #   post.cooked = post.cook(raw)
    #   cpp = CookedPostProcessor.new(post)
    #   cpp.keep_reverse_index_up_to_date
    #   post.save
    # end

    # Post.where("raw like '%[  \n](/gartner%'").each do |post|
    #   raw = post.raw
    #   raw.gsub!(/\)\[  \n\]\(\/gartner/, '")[](/gartner')

    #   post.raw = raw
    #   post.cooked = post.cook(raw)
    #   cpp = CookedPostProcessor.new(post)
    #   cpp.keep_reverse_index_up_to_date
    #   post.save
    # end

    # Post.where("raw like '%### [![](https://gartner.i.lithium.com/t5/image/serverpage/image-id/2671i0DB86CE6EDC546FA/image-size/original%'").each do |post|
    #   raw = post.raw
    #   raw.sub!("### [![](https://gartner.i.lithium.com/t5/image/serverpage/image-id/2671i0DB86CE6EDC546FA/image-size/original", "[![](https://gartner.i.lithium.com/t5/image/serverpage/image-id/2671i0DB86CE6EDC546FA/image-size/original")
    #   raw.sub!("(/gartner/attachments/gartner/Q-N-A/5178/1/IT%20Budget%20-%20Upper%20and%20Lower%20Deviation%20Thresholds%20FY%202016.xlsx)", "")

    #   post.raw = raw
    #   post.cooked = post.cook(raw)
    #   post.save
    # end

    Post.where("raw like '%(/gartner/attachments/gartner/%'").each do |post|
      raw = post.raw
      i = 0
      
      while raw.match(/\(\/gartner\/attachments\/gartner\/([^.]*).(\w*)\)/) && i < 10
        i += 1
        matches = raw.match(/\(\/gartner\/attachments\/gartner\/([^.]*).(\w*)\)/)
        path = "#{matches[1]}.#{matches[2]}"

        segments = path.match(/\/(\d*)\/(\d)\/([^.]*).(\w*)$/)
        if segments
          lithium_post_id = segments[1]
          attachment_number = segments[2]
          # filename = "#{segments[3]}.#{segments[4]}"

          result = mysql_query("select a.attachment_id, f.file_name from tblia_message_attachments a 
                                INNER JOIN message2 m ON a.message_uid = m.unique_id 
                                INNER JOIN tblia_attachment f ON a.attachment_id = f.attachment_id
                                where m.id = #{lithium_post_id} AND a.attach_num = #{attachment_number} limit 0, 1")
          
          result.each do |row|
            attachment_id = row["attachment_id"]
            real_filename = row["file_name"]
            upload, filename = find_upload(post.user_id, attachment_id, real_filename)
            if upload.present?
              raw.sub!("(/gartner/attachments/gartner/#{path})", "(#{upload.url})")
            end
          end
        end
      end

      post.raw = raw
      post.cooked = post.cook(raw)
      post.save
    end

    # Post.where("raw like '%(upload://%'").each do |post|
    #   raw = post.raw
      
    #   matches = raw.match(/\(upload:\/\/([^.]*).(\w*)\)/)
    #   if matches
    #     url = matches[0]
    #     url = url[1...(url.length - 1)]
    #     sha1 = Upload.sha1_from_short_url(url)
    #     full_url = Upload.find_by(sha1: sha1).url

    #     raw = raw.sub!("(#{url})", "(#{full_url})")
    #     post.raw = raw
    #     post.cooked = post.cook(raw)
    #     cpp = CookedPostProcessor.new(post)
    #     cpp.keep_reverse_index_up_to_date
    #     post.save
    #   end
    # end
  end

  # find the uploaded file information from the db
  def find_upload(user_id, attachment_id, real_filename)
    filename = File.join(ATTACHMENT_DIR, "#{attachment_id}.dat")
    unless File.exists?(filename)
      puts "Attachment file doesn't exist: #{filename}"
      return nil
    end
    real_filename.prepend SecureRandom.hex if real_filename[0] == '.'
    upload = create_upload(user_id, filename, real_filename)

    if upload.nil? || !upload.valid?
      puts "Upload not valid :("
      puts upload.errors.inspect if upload
      return nil
    end

    return upload, real_filename
  rescue Mysql2::Error => e
    puts "SQL Error"
    puts e.message
    puts sql
    return nil
  end
end

Attachments.new.perform
