module Admin
  class DisciplinesController < ApplicationController
    before_action :authorize_admin!
    before_action :set_discipline, only: [ :show, :edit, :update, :destroy ]

    def index
      @disciplines = Discipline.includes(:skills).order(:name)
    end

    def show
    end

    def new
      @discipline = Discipline.new
    end

    def edit
    end

    def create
      @discipline = Discipline.new(discipline_params)
      if @discipline.save
        redirect_to admin_discipline_path(@discipline), notice: "Discipline was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @discipline.update(discipline_params)
        redirect_to admin_discipline_path(@discipline), notice: "Discipline was successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @discipline.skills.any?
        redirect_to admin_disciplines_path, alert: "Cannot delete this discipline because it contains #{@discipline.skills.count} skill(s). Remove or reassign the skills first."
        return
      end
      @discipline.destroy
      redirect_to admin_disciplines_path, notice: "Discipline was successfully deleted."
    end

    private

    def set_discipline
      @discipline = Discipline.find_by(slug: params[:id]) || Discipline.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_disciplines_path, alert: "Discipline not found."
    end

    def discipline_params
      params.require(:discipline).permit(:name)
    end
  end
end
