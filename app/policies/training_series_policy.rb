# Authorization for recurring training series.
#
# Every recurring-training action is manager-gated (coach/curator/admin),
# matching the one-off training rule, except the series list: it feeds the
# Training directory's series filter, which is read-only discovery open to
# anyone browsing the shared schedule. Organisation/group ids are schedule
# metadata, not an authorization scope.
class TrainingSeriesPolicy < ApplicationPolicy
  # Single gate used by the controller's before_action; the per-action queries
  # exist for completeness so `authorize series, :show?` etc. also work.
  def access?       = content_manager?
  def preview?      = content_manager?
  def index?        = true
  def show?         = content_manager?
  def create?       = content_manager?
  def sessions?     = content_manager?
  def bulk_cancel?  = content_manager?
  def bulk_delete?  = content_manager?
  def stop?         = content_manager?
  def cancel_future? = content_manager?
  def update_future? = content_manager?
  def split?        = content_manager?
end
