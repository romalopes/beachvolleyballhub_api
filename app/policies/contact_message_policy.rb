# Authorization for the internal Contact Messages inbox (IDENTITY-259).
#
# Reading a public enquiry is platform-staff work: only the global `admin` and
# `curator` roles may list, read or change the status of a message. Those roles
# live on User/Role, platform-wide. Organisation-scoped roles live on
# OrganisationMembership and are a separate concept, so belonging to an
# organisation can never grant access here.
#
# Coaches, players/readers and anonymous visitors are denied — the base policy
# already denies everything a subclass does not explicitly allow.
#
# `user` is the EFFECTIVE user (Current.user), following the app-wide convention
# for content rules: while an admin impersonates somebody, the inbox behaves as
# the impersonated user.
class ContactMessagePolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless platform_staff?

      scope.all
    end

    private

    def platform_staff?
      (user&.admin? || user&.curator?) || false
    end
  end

  def index? = platform_staff?
  def show? = platform_staff?
  # Only the status may change; the permitted attributes are enforced by the
  # controller's strong parameters.
  def update? = platform_staff?

  private

  def platform_staff? = admin? || curator?
end
