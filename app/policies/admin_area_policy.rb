# Gate for the admin namespaces (`/admin/*` and `/api/v1/admin/*`).
#
# Uses the REAL authenticated user so an admin who is impersonating a normal
# user keeps admin authority — the app-wide convention that historically lived
# in `ApplicationController#authorize_admin!`.
#
# Usage: `authorize :admin_area, :access?`
class AdminAreaPolicy < ApplicationPolicy
  def access? = real_admin?
end
