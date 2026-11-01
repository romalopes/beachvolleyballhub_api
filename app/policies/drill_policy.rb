# Authorization for the drill catalogue.
#
# Drills have a creator, a visibility (`shared`/`private`/`unlisted`) and a
# publication status (`draft`/`submitted`/`published`/`archived`/`rejected`).
# The public catalogue exposes only `published` + `shared`; everything else is
# visible only to its creator (and manageable by the owner or an admin).
class DrillPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    # The public drill catalogue. Draft, private, unlisted, archived and
    # rejected drills never appear here — the admin surface lists them all.
    def resolve
      scope.published_and_shared
    end
  end

  # Public reads are allowed; the scope narrows the collection and `show?`
  # decides per record.
  def index? = true

  # A drill is readable when it is published+shared, or by its creator/admin.
  def show?
    record.published_and_shared? || owner? || admin?
  end

  # Coaches and admins create drills (curators are oversight, not authors).
  def create? = coach? || admin?

  # The owner or an admin may modify/delete a drill.
  def update?  = owner? || admin?
  def destroy? = owner? || admin?

  # Visibility is an ownership decision; status transitions are a content
  # manager decision (coach/curator/admin).
  def change_visibility? = owner? || admin?
  def change_status?     = content_manager?

  private

  def owner?
    user.present? && record.respond_to?(:created_by) && record.created_by == user
  end
end
