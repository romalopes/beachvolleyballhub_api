# Idempotent subscription catalogue seed (IDENTITY-116, Phase 2).
#
# Called from db/seeds.rb. Safe to run on every deploy:
#   * a plan/feature is created only when its slug is absent;
#   * an existing plan's price, name and flags are NOT overwritten, so an
#     administrator's catalogue edits survive a reseed;
#   * a missing plan→feature association is added, never removed.
#
# Prices are annual, in cents, AUD. Stripe Price IDs are deliberately not seeded:
# they are environment configuration (STRIPE_<SLUG>_YEARLY_PRICE_ID), so a test
# deployment and a live deployment can point at different Stripe accounts.

plans = [
  { slug: "free",   name: "FREE",   yearly_price_cents: 0,    is_default: true,  owner_scope: "both",         position: 0, popular: false },
  { slug: "player", name: "Player", yearly_price_cents: 500,  is_default: false, owner_scope: "personal",     position: 1, popular: true },
  { slug: "coach",  name: "Coach",  yearly_price_cents: 1000, is_default: false, owner_scope: "personal",     position: 2, popular: false },
  { slug: "club",   name: "Club",   yearly_price_cents: 5000, is_default: false, owner_scope: "organisation", position: 3, popular: false }
]

plans.each do |attributes|
  Subscription.find_or_create_by!(slug: attributes[:slug]) do |plan|
    plan.assign_attributes(attributes.merge(
      currency: "AUD",
      active: true,
      visible: true,
      # Explicit Phase 0 semantics: 0 means "none beyond the documented owner
      # access", not unlimited. nil would mean unlimited/not applicable.
      included_users: 0,
      history_limit: 0
    ))
  end
end

features = [
  { slug: "enhanced_player_profile",    name: "Enhanced personal player profile",          position: 0 },
  { slug: "advanced_training_planning", name: "Advanced training planning",                position: 1 },
  { slug: "advanced_assessments",       name: "Advanced assessments and player development", position: 2 },
  { slug: "organisation_management",    name: "Organisation management",                   position: 3 },
  { slug: "club_reporting",             name: "Club-level reporting and management",       position: 4 }
]

features.each do |attributes|
  SubscriptionFeature.find_or_create_by!(slug: attributes[:slug]) do |feature|
    feature.assign_attributes(attributes.merge(active: true))
  end
end

mappings = {
  "player" => %w[enhanced_player_profile],
  "coach"  => %w[enhanced_player_profile advanced_training_planning advanced_assessments],
  "club"   => %w[enhanced_player_profile advanced_training_planning advanced_assessments organisation_management club_reporting]
}

mappings.each do |plan_slug, feature_slugs|
  plan = Subscription.find_by!(slug: plan_slug)
  next_position = plan.subscription_subscription_features.maximum(:position).to_i
  next_position = -1 if plan.subscription_subscription_features.none?

  feature_slugs.each do |feature_slug|
    feature = SubscriptionFeature.find_by!(slug: feature_slug)
    next if plan.subscription_subscription_features.exists?(subscription_feature_id: feature.id)

    next_position += 1
    plan.subscription_subscription_features.create!(
      subscription_feature: feature,
      position: next_position
    )
  end
end

puts "Seeded #{Subscription.count} subscription plans and #{SubscriptionFeature.count} features"
