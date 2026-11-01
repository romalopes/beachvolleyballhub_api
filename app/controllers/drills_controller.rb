class DrillsController < ApplicationController
  allow_unauthenticated_access

  def index
    # Public HTML view: only published, shared drills. Draft, private,
    # unlisted, archived and rejected drills are never listed here.
    @drills = Drill.published_and_shared.includes(skills: :category).order(:title)
  end

  def show
    @drill = Drill.includes(skills: :category).find_by(slug: params[:id]) ||
             Drill.includes(skills: :category).find_by(id: params[:id])
    return render_not_found unless @drill
    # A drill that is not published+shared is only visible to its creator.
    render_not_found unless @drill.published_and_shared? || current_user == @drill.created_by
  end

  private

  def render_not_found
    render "shared/not_found", status: :not_found
  end
end
