# JSON payloads shared by the tournaments, divisions and watch-link endpoints
# so a shape once defined can never drift between them.
module TournamentPayloads
  extend ActiveSupport::Concern

  private

  def tournament_payload(tournament)
    {
      id: tournament.id,
      name: tournament.name,
      organisation: {
        id: tournament.organisation.id,
        name: tournament.organisation.name,
        acronym: tournament.organisation.acronym
      },
      scope: tournament.scope,
      division_scheme: tournament.division_scheme,
      publication_state: tournament.publication_state,
      website_url: tournament.website_url,
      description: tournament.description,
      location_name: tournament.location_name,
      city: tournament.city,
      state: tournament.state,
      country: tournament.country,
      timezone: tournament.timezone,
      all_day: tournament.all_day,
      starts_at: tournament.starts_at,
      ends_at: tournament.ends_at,
      created_by_account_id: tournament.created_by_account_id,
      divisions: tournament.divisions.map { |d| division_payload(d) },
      participations: tournament.participations.map { |p| participation_payload(p) },
      my_participation: Current.user&.account ? participation_payload(tournament.participations.find_by(account_id: Current.user.account.id)) : nil,
      watch_links: tournament.watch_links.map { |l| watch_link_payload(l) }
    }
  end

  def division_payload(division)
    {
      id: division.id,
      letter_level: division.letter_level,
      division_number: division.division_number,
      active: division.active,
      strength_order: division.strength_order,
      division_code: division.division_code
    }
  end

  def participation_payload(participation)
    return nil unless participation

    {
      id: participation.id,
      account_id: participation.account_id,
      role: participation.role,
      created_at: participation.created_at,
      division_ids: participation.participation_divisions.pluck(:tournament_division_id)
    }
  end

  def watch_link_payload(link)
    {
      id: link.id,
      name: link.name,
      url: link.url,
      provider: link.provider,
      # `link_type` is the contract the frontend consumes (Phase 5/7); the
      # column itself is named `provider`.
      link_type: link.provider,
      description: link.description,
      starts_at: link.starts_at,
      position: link.position,
      # A link goes live at its starts_at; before that it renders as inactive.
      active: link.starts_at <= Time.current
    }
  end
end
