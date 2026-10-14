class TournamentDivision < ApplicationRecord
  belongs_to :tournament

  validates :tournament_id, presence: true
  validates :letter_level, inclusion: { in: %w[B BB BBB A AA AAA AAAA], allow_blank: true }
  validates :division_number, numericality: { only_integer: true, greater_than: 0, allow_nil: true }
  validate :exactly_one_of_letter_or_number

  def exactly_one_of_letter_or_number
    if letter_level.present? && division_number.present?
      errors.add(:base, "Specify either letter level or division number, not both")
    elsif letter_level.blank? && division_number.blank?
      errors.add(:base, "Specify either letter level or division number")
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