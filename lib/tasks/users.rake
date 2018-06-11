desc "Change topic/post ownership of all the topics/posts by a specific user (without creating new revision)"
task "users:change_post_ownership", [:old_username, :new_username, :archetype] => [:environment] do |_, args|
  old_username = args[:old_username]
  new_username = args[:new_username]
  archetype = args[:archetype]
  archetype = archetype.downcase if archetype

  if !old_username || !new_username
    puts "ERROR: Expecting rake users:change_post_ownership[old_username,new_username,archetype]"
    exit 1
  end

  old_user = find_user(old_username)
  new_user = find_user(new_username)

  if archetype == "private"
    posts = Post.private_posts.where(user_id: old_user.id)
  elsif archetype == "public" || !archetype
    posts = Post.public_posts.where(user_id: old_user.id)
  else
    puts "ERROR: Expecting rake users:change_post_ownership[old_username,new_username,archetype] where archetype is public or private"
    exit 1
  end

  puts "Changing post ownership"
  i = 0
  posts.each do |p|
    PostOwnerChanger.new(post_ids: [p.id], topic_id: p.topic.id, new_owner: User.find_by(username_lower: new_user.username_lower), acting_user: User.find_by(username_lower: "system"), skip_revision: true).change_owner!
    putc "."
    i += 1
  end
  puts "", "#{i} posts ownership changed!", ""
end

task "users:merge", [:source_username, :target_username] => [:environment] do |_, args|
  source_username = args[:source_username]
  target_username = args[:target_username]

  if !source_username || !target_username
    puts "ERROR: Expecting rake users:merge[source_username,target_username]"
    exit 1
  end

  source_user = find_user(source_username)
  target_user = find_user(target_username)

  UserMerger.new(source_user, target_user).merge!
  puts "", "Users merged!", ""
end

task "users:rename", [:old_username, :new_username] => [:environment] do |_, args|
  old_username = args[:old_username]
  new_username = args[:new_username]

  if !old_username || !new_username
    puts "ERROR: Expecting rake users:rename[old_username,new_username]"
    exit 1
  end

  changer = UsernameChanger.new(find_user(old_username), new_username)
  changer.change(asynchronous: false)
  puts "", "User renamed!", ""
end

desc "Updates username in quotes and mentions. Use this if the user was renamed before proper renaming existed."
task "users:update_posts", [:old_username, :current_username] => [:environment] do |_, args|
  old_username = args[:old_username]
  current_username = args[:current_username]

  if !old_username || !current_username
    puts "ERROR: Expecting rake users:update_posts[old_username,current_username]"
    exit 1
  end

  user = find_user(current_username)
  Jobs::UpdateUsername.new.execute(
    user_id: user.id,
    old_username: old_username,
    new_username: user.username,
    avatar_template: user.avatar_template)

  puts "", "Username updated!", ""
end

require 'mysql2'

desc "Updates imported sso id."
task "users:sso_id" => [:environment] do |_, args|
  # fields = UserCustomField.where(name: "sso_id", value: "")
  ids = UserCustomField.where(name: "sso_id").order(updated_at: :desc).pluck(:user_id).first(100)
  total = ids.count
  updated = 0

  @client = Mysql2::Client.new(
    host: "localhost",
    username: "root",
    password: "vinkas",
    database: "gartner"
  )

  ids.each do |user_id|
    begin
      user = User.find(user_id)
      import_id = user.custom_fields["import_id"]
      next if import_id.blank?

      result = @client.query("SELECT sso_id FROM users WHERE id = #{import_id}")
      next if result.blank?

      sso_id = result.first["sso_id"]
      next if sso_id.blank?

      # field.value = sso_id
      # field.save!
      if user.custom_fields["sso_id"].to_s != sso_id.to_s
        user.custom_fields["sso_id"] = sso_id
        user.save!
        updated += 1
      end
    rescue => e
      puts import_id
      raise e
      # skip
    end

    print_status(updated, total)
  end

  puts "", "User sso ids are updated!", ""
end

def find_user(username)
  user = User.find_by_username(username)

  if !user
    puts "ERROR: User with username #{username} does not exist"
    exit 1
  end

  user
end
