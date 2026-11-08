# One configured discipline inside an assessment definition, and the weight it
# contributes to the aggregate.
#
# The row belongs to the *definition*, not to an assessment: `assessments` is
# the per-player result table, and a discipline configures the reusable template.
#
# Position is presentation order only — it never enters the calculation (the
# calculation is a sum over weights, which is order-independent). Missing
# positions are filled from the submitted array index by the controller, the
# same way training focuses do it.
class AssessmentCategory < ApplicationRecord
  belongs_to :assessment_definition
  belongs_to :discipline, optional: true
  belongs_to :discipline_custom, optional: true

  # A scored configuration is history: the definition may not drop it out from
  # under the results that already quote it.
  has_many :assessment_category_scores, dependent: :restrict_with_error

  # The optional finer grain inside this area (plan S5). Created but not yet
  # scored — every score row keeps `criterion_id` NULL — so this catalogue is
  # empty in practice today. Destroying the configuration takes its criteria
  # with it, exactly as a definition takes its own children.
  has_many :criteria, -> { order(:position, :id) },
           dependent: :destroy, inverse_of: :assessment_category

  validates :weight, presence: true,
                     numericality: { only_integer: true, greater_than: 0 }
  validates :position, presence: true,
                       numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :discipline_id, uniqueness: { scope: :assessment_definition_id }, allow_nil: true
  validates :discipline_custom_id, uniqueness: { scope: :assessment_definition_id }, allow_nil: true

  validate :source_is_exactly_one
  validate :source_must_exist

  scope :ordered, -> { order(:position, :id) }

  def custom?
    discipline_custom_id.present?
  end

  # Which branch of the XOR this row sits on — serialized so the SPA never has
  # to infer it from which id happens to be null.
  def source_type
    custom? ? "custom_discipline" : "discipline"
  end


  def label
    discipline&.name || discipline_custom&.name
  end

  def metadata
    {
      id: id,
      discipline_id: discipline_id,
      discipline_custom_id: discipline_custom_id,
      weight: weight,
      position: position,
      source_type: source_type,
      label: label,
      discipline: discipline ? { id: discipline.id, name: discipline.name, slug: discipline.slug } : nil,
      discipline_custom: discipline_custom ? discipline_custom.metadata : nil
    }
  end

  private

  # Exactly one source: a standard Discipline XOR a custom one. The database
  # enforces the same rule; mirroring it here turns a constraint violation into
  # a message the coach can act on.
  def source_is_exactly_one
    if discipline_id.present? && discipline_custom_id.present?
      errors.add(:discipline_custom, "must be blank when a discipline is selected")
    elsif discipline_id.blank? && discipline_custom_id.blank?
      errors.add(:base, "Choose a discipline or a custom discipline")
    end
  end

  # A client-supplied id is never trusted: it must name a row that exists,
  # otherwise the foreign key would raise at save time with no usable message.
  def source_must_exist
    errors.add(:discipline, "must exist") if discipline_id.present? && !Discipline.exists?(discipline_id)
    if discipline_custom_id.present? && !DisciplineCustom.exists?(discipline_custom_id)
      errors.add(:discipline_custom, "must exist")
    end
  end
end

