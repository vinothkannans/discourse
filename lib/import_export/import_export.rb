require "import_export/category_structure_exporter"
require "import_export/category_structure_importer"
require "import_export/category_exporter"
require "import_export/category_importer"
require "import_export/topic_exporter"
require "import_export/topic_importer"
require "json"

module ImportExport

  def self.export_data(filename)
    ActiveSupport::HashWithIndifferentAccess.new(File.open(filename, "r:UTF-8") { |f| JSON.parse(f.read) })
  end

  def self.export_categories(include_users, filename = nil)
    ImportExport::CategoryStructureExporter.new(include_users).perform.save_to_file(filename)
  end

  def self.import_categories(filename)
    ImportExport::CategoryStructureImporter.new(export_data(filename)).perform
  end

  def self.export_category(category_id, filename = nil)
    ImportExport::CategoryExporter.new(category_id).perform.save_to_file(filename)
  end

  def self.import_category(filename)
    ImportExport::CategoryImporter.new(export_data(filename)).perform
  end

  def self.export_topics(topic_ids)
    ImportExport::TopicExporter.new(topic_ids).perform.save_to_file
  end

  def self.import_topics(filename)
    ImportExport::TopicImporter.new(export_data(filename)).perform
  end

  def self.export_groups(args = {})
    return export_groups_by_names(args[:names]) if args[:names].present?

    export_groups_by_categories(args[:categories]) if args[:categories].present?
  end

  def self.export_users(args = {})
    return export_groups_by_ids(args[:ids]) if args[:ids].present?

    export_groups_by_groups(args[:groups]) if args[:groups].present?
  end

  def self.new_user_id(external_user_id)
    ucf = UserCustomField.where(name: "import_id", value: "#{external_user_id}#{import_source}").first
    ucf ? ucf.user_id : Discourse::SYSTEM_USER_ID
  end

  def self.new_category_id(external_category_id)
    CategoryCustomField.where(name: "import_id", value: "#{external_category_id}#{import_source}").first.category_id rescue nil
  end

  def self.import_source
    @_import_source ||= "#{ENV['IMPORT_SOURCE'] || ''}"
  end

  CATEGORY_ATTRS = [:id, :name, :color, :created_at, :user_id, :slug, :description, :text_color,
                    :auto_close_hours, :parent_category_id, :auto_close_based_on_last_post,
                    :topic_template, :suppress_from_homepage, :all_topics_wiki, :permissions_params]

  def self.category_attrs(category)
    CATEGORY_ATTRS.inject({}) { |h, a| h[a] = category.send(a); h }
  end

  GROUP_ATTRS = [ :id, :name, :created_at, :mentionable_level, :messageable_level, :visibility_level,
                  :automatic_membership_email_domains, :automatic_membership_retroactive,
                  :primary_group, :title, :grant_trust_level, :incoming_email]

  def self.group_attrs(group)
    GROUP_ATTRS.inject({}) { |h, a| h[a] = group.send(a); h }
  end

  USER_ATTRS = [:id, :email, :username, :name, :created_at, :trust_level, :active, :last_emailed_at]

  def self.user_attrs(user)
    x = USER_ATTRS.inject({}) { |h, a| h[a] = user.send(a); h; }
    x.merge(bio_raw: user.user_profile.bio_raw,
            website: user.user_profile.website,
            location: user.user_profile.location)
  end

  private

    # export groups that are mentioned in category permissions
    def self.export_groups_by_categories(categories)
      group_names = []
      auto_group_names = Group::AUTO_GROUPS.keys.map(&:to_s)

      categories.each do |c|
        c[:permissions_params].each do |group_name, _|
          group_names << group_name unless auto_group_names.include?(group_name.to_s)
        end
      end

      group_names.uniq!
      return [] if group_names.empty?

      export_groups_by_names(group_names)
    end

    def self.export_groups_by_names(names)
      groups = []

      names.each do |name|
        group = Group.find_by_name(name)
        attrs = group_attrs(group)
        attrs[:user_ids] = group.users.pluck(:id)
        groups << attrs
      end

      groups
    end

    def self.export_users_by_groups(groups)
      user_ids = []

      groups.each do |g|
        user_ids += g[:user_ids]
      end

      user_ids.uniq!
      return [] if user_ids.empty?

      export_users(user_ids)
    end

    def self.export_users_by_ids(ids)
      users = []

      # TODO: avatar
      @exported_user_ids = []
      users = User.where(id: user_ids)
      users.each do |u|
        unless @exported_user_ids.include?(u.id)
          users << user_attrs(u)
        end
      end

      users
    end

end
