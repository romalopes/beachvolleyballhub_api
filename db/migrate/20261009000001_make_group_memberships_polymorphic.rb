# frozen_string_literal: true

# Mirror `organisation_memberships` (§4.4 / the polymorphic migration): give a
# GroupMembership an explicit subject so an accountless PlayerProfile or
# CoachProfile can sit on a roster in its own right, exactly as it already can
# on an organisation roster. Existing rows are backfilled to their Account
# first, so nothing about a current roster changes.
#
# `account_id` and its partial unique index are deliberately kept: group
# ownership is Account-only (Group#owner? reads the active owner membership),
# and the (group_id, account_id) uniqueness that index guarantees still has to
# hold for every account-keyed row.
class MakeGroupMembershipsPolymorphic < ActiveRecord::Migration[8.1]
  def up
    add_reference :group_memberships, :memberable, polymorphic: true
    execute <<~SQL
      UPDATE group_memberships
      SET memberable_type = 'Account', memberable_id = account_id
      WHERE account_id IS NOT NULL
    SQL
    change_column_null :group_memberships, :memberable_type, false
    change_column_null :group_memberships, :memberable_id, false
    add_index :group_memberships, %i[group_id memberable_type memberable_id],
      unique: true, name: "index_group_memberships_on_subject"
  end

  def down
    remove_index :group_memberships, name: "index_group_memberships_on_subject"
    remove_reference :group_memberships, :memberable, polymorphic: true
  end
end
