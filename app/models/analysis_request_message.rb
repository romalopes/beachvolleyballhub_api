class AnalysisRequestMessage < ApplicationRecord
  belongs_to :analysis_request, inverse_of: :analysis_request_messages
  belongs_to :account, optional: true
  belongs_to :user, optional: true

  validates :body, presence: true, length: { maximum: 5000 }
  validates :from_submitter, inclusion: { in: [true, false] }
  validates :internal, inclusion: { in: [true, false] }

  scope :visible_to_submitter, -> { where(internal: false).order(:created_at) }
  scope :internal_notes, -> { where(internal: true).order(:created_at) }

  after_create :notify_recipients
  after_create :enqueue_email

  # Display name used in notification copy and API payloads.
  def author_name
    account&.full_name.presence ||
      analysis_request&.guest_name.presence ||
      "Submitter"
  end

  private

  # Internal notes are staff-only by definition: never notify or email the
  # submitter about them.
  def notify_recipients
    return if internal?

    Notifications::WorkflowEvents.analysis_request_message_created(self) if defined?(Notifications::WorkflowEvents)
  end

  def enqueue_email
    return if internal?

    AnalysisRequestMessageEmailJob.perform_later(id)
  end
end