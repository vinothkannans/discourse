desc 'Export all the categories'
task 'categories:export', [:include_group_users, :file_name] => [:environment] do |_, args|
  require "import_export/import_export"

  ImportExport.export_categories(args[:include_group_users], args[:file_name])
  puts "", "Done", ""
end

desc 'Import the categories'
task 'categories:import', [:file_name] => [:environment] do |_, args|
  require "import_export/import_export"

  ImportExport.import_categories(args[:file_name])
  puts "", "Done", ""
end
