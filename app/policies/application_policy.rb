# Base class for every Pundit policy in the application.
#
# The "user" passed to a policy is the EFFECTIVE user (Current.user): while an
# admin is impersonating somebody, content and ownership rules must act as the
# impersonated user. Site-administration rules that must survive impersonation
# (the same ones that historically used `Current.real_user`) call `real_admin?`,
# which reads the real authenticated user directly.
#
# `Current` is request-scoped (ActiveSupport::CurrentAttributes), so policies
# read `Current.real_user` without threading a second argument through.
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  # Deny by default: a policy that does not implement an action refuses it.
  def index?   = false
  def show?    = false
  def create?  = false
  def new?     = create?
  def update?  = false
  def edit?    = update?
  def destroy? = false

  # ----- role helpers (effective user) ---------------------------------------
  def admin?   = user&.admin? || false
  def curator? = user&.curator? || false
  def coach?   = user&.coach? || false
  def player?  = user&.player? || false
  def content_manager? = user&.content_manager? || false
  def account  = user&.account

  # ----- real (non-impersonated) helpers -------------------------------------
  # Site administration uses the REAL authenticated user so an impersonating
  # admin keeps admin authority (the app-wide convention).
  def real_user  = Current.real_user
  def real_admin? = real_user&.admin? || false

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    # Subclasses must implement `resolve`.
    def resolve
      raise NoMethodError, "#{self.class} must implement #resolve"
    end
  end
end
