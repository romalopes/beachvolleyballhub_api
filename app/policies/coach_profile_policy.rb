class CoachProfilePolicy < ProfilePolicy
  def create? = create_coach?
end
