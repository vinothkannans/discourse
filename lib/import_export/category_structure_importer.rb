require File.join(Rails.root, 'script', 'import_scripts', 'base.rb')

module ImportExport
  class CategoryStructureImporter < ImportScripts::Base
    def initialize(export_data)
      @export_data = export_data
    end

    def perform
      RateLimiter.disable

      import_users
      import_groups
      import_categories
      self
    ensure
      RateLimiter.enable
    end

    def import_users
      @export_data[:users].each do |u|
        import_id = "#{u[:id]}#{ImportExport.import_source}"
        existing = User.with_email(u[:email]).first
        if existing
          if existing.custom_fields["import_id"] != import_id
            existing.custom_fields["import_id"] = import_id
            existing.save!
          end
        else
          u = create_user(u, import_id) # see ImportScripts::Base
        end
      end
      self
    end

    def import_groups
      return if @export_data[:groups].empty?

      @export_data[:groups].each do |group_data|
        g = group_data.dup
        user_ids = g.delete(:user_ids)
        external_id = g.delete(:id)
        new_group = Group.find_by_name(g[:name]) || Group.create!(g)
        user_ids.each do |external_user_id|
          new_user_id = ImportExport.new_user_id(external_user_id)
          next if new_user_id == Discourse::SYSTEM_USER_ID
          new_group.add(User.find(new_user_id)) rescue ActiveRecord::RecordNotUnique
        end
      end
    end

    def import_categories
      @export_data[:categories].each do |cat_attrs|
        id = cat_attrs.delete(:id)
        import_id = "#{id}#{ImportExport.import_source}"

        existing = CategoryCustomField.where(name: 'import_id', value: import_id).first.try(:category)

        unless existing
          permissions = cat_attrs.delete(:permissions_params)
          category = Category.new(cat_attrs)
          category.user_id = ImportExport.new_user_id(cat_attrs[:user_id]) # imported user's new id
          category.custom_fields["import_id"] = import_id
          category.permissions = permissions.present? ? permissions : { "everyone" => CategoryGroup.permission_types[:full] }
          saved = category.save
          set_category_description(category, cat_attrs[:description]) if saved
        end
      end

      @export_data[:subcategories].each do |cat_attrs|
        id = cat_attrs.delete(:id)
        import_id = "#{id}#{ImportExport.import_source}"
        existing = CategoryCustomField.where(name: 'import_id', value: import_id).first.try(:category)

        unless existing
          permissions = cat_attrs.delete(:permissions_params)
          subcategory = Category.new(cat_attrs)
          subcategory.parent_category_id = cat_attrs[:parent_category_id]
          subcategory.user_id = ImportExport.new_user_id(cat_attrs[:user_id])
          subcategory.custom_fields["import_id"] = import_id
          subcategory.permissions = permissions.present? ? permissions : { "everyone" => CategoryGroup.permission_types[:full] }
          saved = subcategory.save
          set_category_description(subcategory, cat_attrs[:description]) if saved
        end
      end
    end

    def set_category_description(c, description)
      return unless description.present?

      post = c.topic.ordered_posts.first
      post.raw = description
      post.save!
      post.rebake!
    end

  end
end
