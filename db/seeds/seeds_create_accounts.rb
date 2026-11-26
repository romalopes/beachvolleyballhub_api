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
  { email_address: "romalopes@yahoo.com.br",     role: "admin",     first_name: "Anderson Yahoo",    last_name: "Lopes" },
  { email_address: "kasia@mywineadviser.com.au", role: "curator",   first_name: "Kasia",     last_name: "Sobiesiak" },
  { email_address: "romalopes@gmail.com",        role: "coach",     first_name: "Anderson Gmail",    last_name: "Lopes" },
  { email_address: "coach@yahoo.com.br",         role: "coach",     first_name: "Coach",     last_name: "Account" },
  { email_address: "player@yahoo.com.br",        role: "player",    first_name: "Player",    last_name: "Account" }
]

account_definitions.each do |attributes|
  user = User.find_or_initialize_by(email_address: attributes[:email_address])
  user.password = password
  user.email_verified_at ||= Time.current
  user.save!

  role = Role.find_or_create_by!(name: attributes[:role])
  user.user_roles.where.not(role_id: role.id).delete_all
  user.add_role(role.name)

  # Create or update the associated Account with contact details
  account = user.account || user.build_account
  account.save! if account.new_record? # Create the account first if new
  account.first_name = attributes[:first_name]
  account.last_name = attributes[:last_name]
  account.email = attributes[:email_address] # Sync email to contact_detail
  account.save!

  puts "#{user.email_address} -> #{role.name} (Account: #{account.full_name})"
end

puts "Created or updated #{account_definitions.size} accounts."
