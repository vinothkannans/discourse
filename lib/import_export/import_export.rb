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

end
