module LocationPayloads
  extend ActiveSupport::Concern

  private

  def location_summary(location)
    location&.summary
  end

  def location_detail(location)
    location.summary.merge(
      aliases: location.aliases.order(:name).map do |row|
        { id: row.id, name: row.name, source: row.source }
      end,
      courts: location.courts.ordered.map(&:summary),
      source: location.source,
      source_reference: location.source_reference,
      proposed_by_account_id: location.proposed_by_account_id,
      verified_by_account_id: location.verified_by_account_id,
      verified_at: location.verified_at,
      archived_at: location.archived_at,
      merged_into_id: location.merged_into_id,
      can_edit: location_oversight?
    )
  end

  def location_oversight?
    Current.user&.admin? || Current.user&.curator?
  end
end
