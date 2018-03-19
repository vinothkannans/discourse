require File.expand_path("../../config/environment", __FILE__)

class MigrateMentions

  def print_status(current, start_time = nil)
    if start_time.present?
      elapsed_seconds = Time.now - start_time
      elements_per_minute = '[%.0f items/min]  ' % [current / elapsed_seconds.to_f * 60]
    else
      elements_per_minute = ''
    end

    print "\r%9d %s" % [current, elements_per_minute]
  end

  def perform
    SiteSetting.min_post_length = 2
    Rails.logger.level = 3
    puts "Started..."
    li_user_with_login
    #li_user_without_login
    puts "...Finished"
    SiteSetting.min_post_length = 20
  end

  def li_user_with_login
    current = 0
    Post.where("raw like '%<li-user uid=% login=%>%</li-user>%'").find_each do |post|
      begin
        raw = post.raw.dup

        while data = raw.match(/<li-user uid="(\d*)" login="@?[^<]+">\??<\/li-user>/)
          old_mention = data[0]
          uid = data[1]
          user = UserCustomField.find_by(name: 'import_id', value: uid).try(:user)
          new_mention = user.present? ? "@#{user.username}" : old_mention.sub(" uid=", " problem_uid=")
          raw.sub!(old_mention, new_mention)
        end

        if post.raw != raw
          post.raw = raw
          post.save!
          post.rebake!
        end
      rescue => e
        puts "Got a error on post: #{post.id} #{e}"
        raise e
      ensure
        print_status(current += 1)
      end
    end
  end

  def li_user_without_login
    current = 0
    Post.where("raw like '%<li-user uid=%></li-user>%'").find_each do |post|
      begin
        raw = post.raw.dup

        while data = raw.match(/<li-user uid="(\d*)"><\/li-user>/)
          old_mention = data[0]
          uid = data[1]
          user = UserCustomField.find_by(name: 'import_id', value: uid).try(:user)
          new_mention = user.present? ? "@#{user.username}" : old_mention.sub(" uid=", " problem_uid=")
          raw.sub!(old_mention, new_mention)
        end

        if post.raw != raw
          post.raw = raw
          post.save!
          post.rebake!
        end
      rescue => e
        puts "Got a error on post: #{post.id} #{e}"
        raise e
      ensure
        print_status(current += 1)
      end
    end
  end

end

MigrateMentions.new.perform
