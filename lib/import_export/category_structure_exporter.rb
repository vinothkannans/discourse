module ImportExport
  class CategoryStructureExporter

    attr_reader :export_data

    def initialize(include_users)
      @include_users = include_users.present?
      @categories = Category.where(parent_category_id: nil)
      @subcategories = Category.where.not(parent_category_id: nil)
      @export_data = {
        groups: [],
        categories: [],
        subcategories: []
      }
      @export_data[:users] = [] if @include_users
    end

    def perform
      puts "Exporting all the categories...", ""
      export_categories
      export_groups
      export_users if @include_users

      self
    end

    def export_categories
      @categories.find_each do |cat|
        @export_data[:categories] << ImportExport.category_attrs(cat)
      end

      self
    end

    def export_groups
      categories = @export_data[:categories] + @export_data[:subcategories]
      @export_data[:groups] = ImportExport.export_groups(categories: categories)

      self
    end

    def export_users
      @export_data[:users] = ImportExport.export_users(groups: @export_data[:groups])

      self
    end

    def save_to_file(filename = nil)
      require 'json'
      output_basename = filename || File.join("categories-export-#{Time.now.strftime("%Y-%m-%d-%H%M%S")}.json")
      File.open(output_basename, "w:UTF-8") do |f|
        f.write(@export_data.to_json)
      end
      puts "Export saved to #{output_basename}"
      output_basename
    end

  end
end
