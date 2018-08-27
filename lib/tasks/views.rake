desc 'Import views from csv file'
task 'import:views', [:file_name] => [:environment] do |_, args|
  csv_text = File.read(args[:file_name])
  csv = CSV.parse(csv_text, :headers => true)
  csv.each do |row|
    views = row["VIEWS_COUNT"].to_i
    if views == 0
      puts "-"
      next
    end

    message_id = row["MESSAGE_ID"]
    topic = PostCustomField.find_by(name: "import_unique_id", value: message_id).try(:post).try(:topic)
    if topic.blank?
      puts "#{message_id} topic not found"
      next
    end

    topic.views += views
    if topic.save
      puts "."
    else
      puts "X"
    end
  end
  puts "", "Done", ""
end

desc 'Import logins from csv file'
task 'import:logins', [:file_name] => [:environment] do |_, args|
  csv_text = File.read(args[:file_name])
  csv = CSV.parse(csv_text, :headers => true)
  csv.each do |row|
    lithium_id = row["LITHIUM_ID"]
    user = UserCustomField.find_by(name: "import_id", value: lithium_id).try(:user)
    if user.blank?
      puts "#{lithium_id} user not found"
      next
    end

    last_login_date = DateTime.strptime(row["LAST_LOGIN_DT"], '%m/%d/%Y %H:%M:%S')
    if user.last_seen_at >= last_login_date
      puts "#{lithium_id} #{user.id} ---"
      next
    end

    user.last_seen_at = last_login_date
    if user.save
      puts "."
    else
      puts "X"
    end
  end
  puts "", "Done", ""
end
