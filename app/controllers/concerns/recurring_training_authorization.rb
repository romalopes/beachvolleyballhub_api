# Gate for the recurring-training API surface.
#
# The feature ships behind an environment flag so migrations can run and the API
# can be deployed before the SPA is released:
#
#   RECURRING_TRAINING_ENABLED=false  -> new endpoints return 404
#   unset / true                      -> endpoints are available
#
# Existing one-off training-session endpoints are deliberately NOT gated: they
# are core functionality and keep working in either state.
module RecurringTrainingAuthorization
  extend ActiveSupport::Concern

  included do
    before_action :ensure_recurring_training_enabled!
  end

  private

  def ensure_recurring_training_enabled!
    return if recurring_training_enabled?

    render json: { error: "Recurring training is not available" }, status: :not_found
  end

  def recurring_training_enabled?
    ActiveModel::Type::Boolean.new.cast(
      ENV.fetch("RECURRING_TRAINING_ENABLED", "true")
    )
  end
end
