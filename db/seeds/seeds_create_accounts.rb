# Create the five requested accounts.
# Run with:
#   bin/rails runner db/seeds/seeds_create_accounts.rb
#
# The application stores the email in `users.email_address` and assigns roles
# through the User#add_role method. The password must be supplied by dotenv
# through DB_PASSWORD in the relevant .env file.

password = ENV.fetch("DB_PASSWORD") do
  abort "DB_PASSWORD is not set. Add DB_PASSWORD to your .env file before running this seed."
end

account_definitions = [
  { email_address: "romalopes@yahoo.com.br",     role: "admin" },
  { email_address: "kasia@mywineadviser.com.au", role: "curator" },
  { email_address: "romalopes@gmail.com",        role: "coach" },
  { email_address: "coach@yahoo.com.br",         role: "coach" },
  { email_address: "player@yahoo.com.br",        role: "player" }
]

account_definitions.each do |attributes|
  user = User.find_or_initialize_by(email_address: attributes[:email_address])
  user.password = password
  user.email_verified_at ||= Time.current
  user.save!

  role = Role.find_or_create_by!(name: attributes[:role])
  user.user_roles.where.not(role_id: role.id).delete_all
  user.add_role(role.name)

  puts "#{user.email_address} -> #{role.name}"
end

puts "Created or updated #{account_definitions.size} accounts."
