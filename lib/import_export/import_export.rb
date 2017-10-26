require "import_export/categories_exporter"
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
    ImportExport::CategoriesExporter.new(include_users).perform.save_to_file(filename)
  end

  def self.import_categories(filename)
    ImportExport::CategoriesImporter.new(export_data(filename)).perform
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

end
