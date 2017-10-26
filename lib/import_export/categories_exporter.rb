module ImportExport
  class CategoriesExporter

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
      self
    end

    def export_categories
      @categories.find_each do |cat|
        @export_data[:categories] << ImportExport.category_attrs(cat)
      end
      @subcategories.find_each do |subcat|
        @export_data[:subcategories] << ImportExport.category_attrs(subcat)
      end

      # export groups that are mentioned in category permissions
      group_names = []
      auto_group_names = Group::AUTO_GROUPS.keys.map(&:to_s)

      (@export_data[:categories] + @export_data[:subcategories]).each do |c|
        c[:permissions_params].each do |group_name, _|
          group_names << group_name unless auto_group_names.include?(group_name.to_s)
        end
      end

      group_names.uniq!
      export_groups(group_names) unless group_names.empty?

      if @include_users
        # export group users
        user_ids = []

        @export_data[:groups].each do |g|
          user_ids += g[:user_ids]
        end

        user_ids.uniq!
        export_users(user_ids) unless user_ids.empty?
      end

      self
    end

    def export_groups(group_names)
      group_names.each do |name|
        group = Group.find_by_name(name)
        group_attrs = ImportExport::group_attrs(group)
        group_attrs[:user_ids] = group.users.pluck(:id)
        @export_data[:groups] << group_attrs
      end

      self
    end

    def export_users(user_ids)
      # TODO: avatar
      @exported_user_ids = []
      users = User.where(id: user_ids)
      users.each do |u|
        unless @exported_user_ids.include?(u.id)
          @export_data[:users] << ImportExport::user_attrs(u)
          @exported_user_ids << u.id
        end
      end

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
