desc 'Import views from csv file'
task 'import:views', [:file_name] => [:environment] do |_, args|
  csv_text = File.read(args[:file_name])
  csv = CSV.parse(csv_text, :headers => true)
  csv.each do |row|
    puts "", row.to_hash
  end
  puts "", "Done", ""
end
