# Server-side subscription entitlement enforcement (IDENTITY-116, Phase 8).
#
# Included by controllers whose operations are sold as premium features. The
# check deliberately sits in the controller/policy boundary: React hiding a button
# is a UX nicety, never authorization.
#
# Three rules keep this from becoming a second, competing authorization system:
#   * role authorization (admin/curator/coach, organisation membership) still runs
#     first and is unaffected — a Coach on FREE is still a Coach, they simply
#     cannot use a premium Coach feature;
#   * the owner context is explicit at every call site (`:personal` or
#     `:organisation`) so a club's subscription can never unlock a personal
#     feature or vice versa;
#   * enforcement is opt-in per environment. Until a deployment flips
#     BILLING_ENFORCEMENT_ENABLED on, behaviour is exactly as before, which is what
#     lets the catalogue be agreed before customers feel it.
module SubscriptionEntitlement
  extend ActiveSupport::Concern

  private

  # Renders a 403 with a stable code and only safe upgrade metadata when the
  # owner is not entitled to +feature_slug+.
  def require_subscription_feature!(feature_slug, owner: :personal)
    return unless Billing::Configuration.enforcement_enabled?
    return if Current.user.nil?
    # Site oversight is not a subscription product.
    return if Current.user.admin? || Current.user.curator?

    entitlement_owner = subscription_owner_for(owner)
    return if entitlement_owner.blank?

    resolver = Entitlements::Resolver.new(entitlement_owner)
    return if resolver.feature_enabled?(feature_slug)

    suggested = resolver.suggested_plan_for(feature_slug)
    render json: {
      error: "This feature requires a subscription",
      code: "subscription_feature_required",
      feature: feature_slug.to_s,
      current_plan: resolver.plan&.slug,
      suggested_plan: suggested && {
        slug: suggested.slug,
        name: suggested.name,
        yearly_price_cents: suggested.yearly_price_cents,
        currency: suggested.currency
      }
    }, status: :forbidden
  end

  def subscription_owner_for(scope)
    case scope
    when :organisation then @organisation
    when :personal then Current.user&.account
    end
  end
end
