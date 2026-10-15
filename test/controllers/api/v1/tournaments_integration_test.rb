require 'test_helper'

class TournamentManagementIntegrationTest < ActiveSupport::TestCase
  include SessionTestHelper

  setup do
    @organisation = Organisation.create!(name: 'Integration Org', acronym: 'IO')
    @admin_account = create_account!(first_name: 'Admin', last_name: 'Admin', email: 'admin@example.com')
    @regular_account = create_account!(first_name: 'Regular', last_name: 'Regular', email: 'regular@example.com')

    # Make admin a superuser (admin? true) - adjust as per your app's admin flag
    @admin_account.update!(admin: true)

    # Ensure both accounts are active members of the organization
    @organisation.organisation_memberships.create!(account_id: @admin_account.id, role: 'administrator', status: 'active')
    @organisation.organisation_memberships.create!(account_id: @regular_account.id, role: 'member', status: 'active')
  end

  test 'admin account can cancel a tournament' do
    tournament = Tournament.create!(
      name: 'Cancel Test Admin',
      organisation_id: @organisation.id,
      created_by_account_id: @regular_account.id,
      scope: 'club',
      division_scheme: 'letter',
      starts_at: '2026-10-15 09:00:00',
      ends_at: '2026-10-15 17:00:00',
      timezone: 'US/Eastern',
      all_day: false,
      publication_state: :active
    )

    # Sign in as admin account
    sign_in_as(@admin_account)

    cancelled = TournamentCancelService.call(tournament)

    assert_equal 'cancelled', cancelled.publication_state
  end

  test 'admin impersonating regular user cannot cancel' do
    tournament = Tournament.create!(
      name: 'Cancel Test Impersonation',
      organisation_id: @organisation.id,
      created_by_account_id: @regular_account.id,
      scope: 'club',
      division_scheme: 'letter',
      starts_at: '2026-10-15 09:00:00',
      ends_at: '2026-10-15 17:00:00',
      timezone: 'US/Eastern',
      all_day: false,
      publication_state: :active
    )

    # Sign in as regular account, then impersonate admin
    sign_in_as(@regular_account)
    # Simulate impersonation by swapping Current.real_user to admin
    Current.real_user = @admin_account

    error = assert_raises ActiveRecord::RecordInvalid do
      TournamentCancelService.call(tournament)
    end

    assert_match(/Forbidden/, error.message)
    # Reset Current.real_user for subsequent tests
    Current.real_user = nil
  end
end