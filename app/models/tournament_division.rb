class TournamentDivision < ApplicationRecord
  belongs_to :tournament
  # Referenced divisions must be retired, never deleted, so a raw destroy of a
  # linked row should surface as a validation error rather than a FK violation.
  has_many :participation_divisions,
           class_name: "TournamentParticipationDivision",
           dependent: :restrict_with_error

  validates :tournament_id, presence: true
  validates :letter_level, inclusion: { in: %w[B BB BBB A AA AAA AAAA], allow_blank: true }
  validates :division_number, numericality: { only_integer: true, greater_than: 0, allow_nil: true }
  validates :letter_level, uniqueness: { scope: :tournament_id }, allow_nil: true
  validates :division_number, uniqueness: { scope: :tournament_id }, allow_nil: true
  validate :exactly_one_of_letter_or_number
  validate :matches_tournament_scheme

  scope :active, -> { where(active: true) }

  def exactly_one_of_letter_or_number
    if letter_level.present? && division_number.present?
      errors.add(:base, "Specify either letter level or division number, not both")
    elsif letter_level.blank? && division_number.blank?
      errors.add(:base, "Specify either letter level or division number")
    end
  end

  # Letter and numbered schemes are not interchangeable: a letter tournament
  # only accepts letter levels and a numbered tournament only numbers.
  def matches_tournament_scheme
    return if tournament.nil?

    if letter_level.present? && tournament.division_scheme != "letter"
      errors.add(:letter_level, "can only be used when the tournament uses the letter scheme")
    elsif division_number.present? && tournament.division_scheme != "numbered"
      errors.add(:division_number, "can only be used when the tournament uses the numbered scheme")
    end
  end

  # Strength order for sorting divisions
  def strength_order
    if letter_level.present?
      case letter_level
      when 'AAAA' then 1
      when 'AAA'  then 2
      when 'AA'   then 3
      when 'A'    then 4
      when 'BBB'  then 5
      when 'BB'   then 6
      when 'B'    then 7
      else 0
      end
    else
      division_number.to_i
    end
  end

  # Unique division code within tournament (letter or number)
  def division_code
    letter_level || division_number.to_s
  end
end