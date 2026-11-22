class SkillsController < ApplicationController
  allow_unauthenticated_access

  def index
    @disciplines = Discipline.order(:name)
    # Public HTML view: only published, shared skills (matches SkillPolicy#show?).
    @skills = Skill.published_and_shared.includes(:discipline).order(:title)
  end

  def show
    @skill = Skill.published_and_shared.includes(:discipline).find_by(slug: params[:id]) ||
             Skill.published_and_shared.includes(:discipline).find_by(id: params[:id])
    return render_not_found unless @skill

    @related_drills = @skill.drills.published_and_shared.includes(skills: :discipline).order(:title)
  end

  private

  def render_not_found
    render "shared/not_found", status: :not_found
  end
end
