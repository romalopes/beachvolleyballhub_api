module Admin
  class SkillsController < ApplicationController
    before_action :authorize_admin!
    before_action :set_skill, only: [ :show, :edit, :update, :destroy ]

    def index
      @filters = filter_params
      @skills = filtered_skills(@filters)
      @disciplines = Discipline.order(:name)
    end

    def show
    end

    def new
      @skill = Skill.new
      @disciplines = Discipline.order(:name)
    end

    def edit
      @disciplines = Discipline.order(:name)
    end

    def create
      @skill = Skill.new(skill_params)
      @disciplines = Discipline.order(:name)
      if @skill.save
        redirect_to admin_skill_path(@skill), notice: "Skill was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      @disciplines = Discipline.order(:name)
      if @skill.update(skill_params)
        redirect_to admin_skill_path(@skill), notice: "Skill was successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @skill.drills.any?
        redirect_to admin_skills_path, alert: "Cannot delete this skill because it is used by #{@skill.drills.count} drill(s)."
        return
      end
      @skill.destroy
      redirect_to admin_skills_path, notice: "Skill was successfully deleted."
    end

    private

    def set_skill
      @skill = Skill.find_by(slug: params[:id]) || Skill.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_skills_path, alert: "Skill not found."
    end

    def skill_params
      params.require(:skill).permit(:title, :discipline_id, :description)
    end

    SORT_OPTIONS = %w[name-asc name-desc discipline].freeze

    def filter_params
      params.permit(:q, :discipline_id, :sort).to_h
    end

    def filtered_skills(filters)
      scope = Skill.includes(:discipline, :drills)

      q = filters[:q].to_s.strip
      if q.present?
        scope = scope.where("skills.title ILIKE ?", "%#{Skill.sanitize_sql_like(q)}%")
      end

      discipline_id = Integer(filters[:discipline_id].to_s, exception: false)
      if discipline_id && Discipline.exists?(discipline_id)
        scope = scope.where(discipline_id: discipline_id)
      end

      case filters[:sort].to_s
      when "name-desc"
        scope.order(title: :desc)
      when "discipline"
        scope.left_joins(:discipline).order(Arel.sql("disciplines.name ASC NULLS LAST, skills.title ASC"))
      else
        scope.order(title: :asc)
      end
    end
  end
end
