class PlayerProfilePolicy < ProfilePolicy
  def create? = create_player?
end
