# Phase 7 — Frontend Visibility Settings & Indicators

**Status:** 🟡 In Progress (started 24 November 2026)
**Parent plan:** `../beachvolleyballhub_assessment_session_visibility_plan.md` (§7 Phase 7)
**Depends on:** Phase 6 complete

## Goal

Implement frontend components for:
1. Visibility selector in session creation/edit forms
2. Visibility badges/indicators in session list and detail views
3. Share button and modal for unlisted sessions
4. TypeScript types for new API fields

## Implementation checklist

- [ ] Update TypeScript types for `AssessmentSession` with `visibility`, `public_slug`
- [ ] Add `AssessmentSessionVisibility` type (enum: 'public' | 'unlisted' | 'internal' | 'private')
- [ ] Create `VisibilityBadge` component (color-coded per visibility)
- [ ] Create `VisibilitySelector` component for forms
- [ ] Update `AssessmentSessionForm` to include visibility selector
- [ ] Update `AssessmentSessionDetail` to show visibility badge and share button
- [ ] Add share modal component for unlisted sessions
- [ ] Update `AssessmentSessions` list to show visibility badges
- [ ] Add API client methods for slug-based show, share token show, regenerate share link
- [ ] Tests: component tests for new components

## Files to touch

- `beachvolleyballhub/src/api.ts` (types + API methods)
- `beachvolleyballhub/src/components/assessments/VisibilityBadge.tsx`
- `beachvolleyballhub/src/components/assessments/VisibilitySelector.tsx`
- `beachvolleyballhub/src/components/assessments/ShareModal.tsx`
- `beachvolleyballhub/src/pages/AssessmentSessionDetail.tsx`
- `beachvolleyballhub/src/pages/AssessmentSessions.tsx`
- `beachvolleyballhub/src/components/assessments/AssessmentSessionForm.tsx` (if exists)

## Acceptance criteria

- [ ] Visibility selector works in create/edit forms
- [ ] Visibility badges display correctly in list and detail views
- [ ] Share button appears only for unlisted sessions (management users)
- [ ] Share modal copies link to clipboard and shows WhatsApp share
- [ ] API client methods work for new endpoints
- [ ] Component tests pass