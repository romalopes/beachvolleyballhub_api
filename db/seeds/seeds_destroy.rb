# Destroy all application records while preserving the database schema.
# Run with:
#   bin/rails runner db/seeds/seeds_destroy.rb
#
# Foreign-key checks are disabled only for the duration of this operation so
# that tables can be cleared regardless of their dependency order.

connection = ActiveRecord::Base.connection
Rails.application.eager_load!
models = ApplicationRecord.descendants
deleted_records = 0

connection.disable_referential_integrity do
  models.reverse_each do |model|
    next if model.abstract_class?
    next unless model.table_exists?

    puts "Destroying records from #{model.table_name}..."
    deleted_records += model.delete_all
  end
end

puts "Destroyed #{deleted_records} records from #{models.count(&:table_exists?)} application tables."