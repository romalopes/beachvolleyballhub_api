# Transactional rules for tournament divisions (Phases 2/4):
# - scheme match and code uniqueness are model validations (letter ↔ numbered);
# - the codes of referenced divisions are locked — retire, don't rewrite the
#   history a participant selected against;
# - the final active division can never be deactivated or removed, because
#   publishing requires at least one active division;
# - destroying a referenced division retires it (active: false) instead of
#   deleting the row.
#
# Every mutation locks the parent tournament so concurrent division and
# participation writes serialize on the same row.
class TournamentDivisionService
  extend InvalidRecord

  class << self
    def create(tournament, attributes)
      ActiveRecord::Base.transaction do
        tournament.lock!

        division = tournament.divisions.new(attributes)
        division.save!
        division
      end
    end

    def update(division, attributes)
      ActiveRecord::Base.transaction do
        tournament = division.tournament
        tournament.lock!

        if code_change?(division, attributes) && referenced?(division)
          raise_invalid!(
            division,
            "Division code cannot be changed while participations reference it — retire it instead"
          )
        end

        if division.active? && attributes.key?(:active) &&
           !ActiveModel::Type::Boolean.new.cast(attributes[:active])
          guard_final_active!(division)
        end

        division.assign_attributes(attributes)
        division.save!
        division
      end
    end

    # Returns { division:, retired: } — referenced divisions come back retired
    # (inactive, row kept); unreferenced ones are deleted outright.
    def destroy(division)
      ActiveRecord::Base.transaction do
        tournament = division.tournament
        tournament.lock!

        if referenced?(division)
          if division.active?
            guard_final_active!(division)
            division.update!(active: false)
          end
          { division: division.reload, retired: true }
        else
          guard_final_active!(division) if division.active?
          division.destroy!
          { division: division, retired: false }
        end
      end
    end

    private

    def referenced?(division)
      TournamentParticipationDivision.exists?(tournament_division_id: division.id)
    end

    def code_change?(division, attributes)
      (attributes.key?(:letter_level) && attributes[:letter_level] != division.letter_level) ||
        (attributes.key?(:division_number) &&
          attributes[:division_number].to_i != division.division_number.to_i)
    end

    def guard_final_active!(division)
      other_active = division.tournament.divisions
                              .active
                              .where.not(id: division.id)
                              .exists?
      return if other_active

      raise_invalid!(
        division,
        "The final active division cannot be deactivated or removed"
      )
    end
  end
end
