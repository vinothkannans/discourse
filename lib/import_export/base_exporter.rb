module ImportExport
  class BaseExporter

    attr_reader :export_data, :categories

    CATEGORY_ATTRS = [:id, :name, :color, :created_at, :user_id, :slug, :description, :text_color,
                      :auto_close_hours, :parent_category_id, :auto_close_based_on_last_post,
                      :topic_template, :suppress_from_homepage, :all_topics_wiki, :permissions_params]

    GROUP_ATTRS = [ :id, :name, :created_at, :mentionable_level, :messageable_level, :visibility_level,
                    :automatic_membership_email_domains, :automatic_membership_retroactive,
                    :primary_group, :title, :grant_trust_level, :incoming_email]

    USER_ATTRS = [:id, :email, :username, :name, :created_at, :trust_level, :active, :last_emailed_at]

    def categories
      @categories ||= Category.all.to_a
    end

    def export_categories
      data = []

      categories.each do |cat|
        data << CATEGORY_ATTRS.inject({}) { |h, a| h[a] = cat.send(a); h }
      end

      data
    end

    def export_categories!
      @export_data[:categories] = export_categories

      self
    end

    # export groups that are mentioned in category permissions
    def export_category_groups
      groups = []
      group_names = []
      auto_group_names = Group::AUTO_GROUPS.keys.map(&:to_s)

      @export_data[:categories].each do |c|
        c[:permissions_params].each do |group_name, _|
          group_names << group_name unless auto_group_names.include?(group_name.to_s)
        end
      end

      group_names.uniq!
      return [] if group_names.empty?

      Group.where(name: group_names).find_each do |group|
        attrs = GROUP_ATTRS.inject({}) { |h, a| h[a] = group.send(a); h }
        attrs[:user_ids] = group.users.pluck(:id)
        groups << attrs
      end

      groups
    end

    def export_category_groups!
      @export_data[:groups] = export_category_groups

      self
    end

    def export_group_users
      users = []
      user_ids = []

      @export_data[:groups].each do |g|
        user_ids += g[:user_ids]
      end

      user_ids.uniq!
      return [] if user_ids.empty?

      # TODO: avatar
      User.where(id: user_ids).each do |u|
        x = USER_ATTRS.inject({}) { |h, a| h[a] = u.send(a); h; }
        x.merge(bio_raw: u.user_profile.bio_raw,
                website: u.user_profile.website,
                location: u.user_profile.location)
        users << x
      end

      users
    end

    def export_group_users!
      @export_data[:users] = export_group_users

      self
    end

    def default_filename_prefix
      raise "Overwrite me!"
    end

    def save_to_file(filename = nil)
      output_basename = filename || File.join("#{default_filename_prefix}-#{Time.now.strftime("%Y-%m-%d-%H%M%S")}.json")
      File.open(output_basename, "w:UTF-8") do |f|
        f.write(@export_data.to_json)
      end
      puts "Export saved to #{output_basename}"
      output_basename
    end

  end
end
