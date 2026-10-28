# Weather Advisor Feature and My Tournaments/My Training Toggles

## Implementation Summary

### Changes to `Home.tsx`

#### 1. Added Toggle State Variables (lines 113-114)

```typescript
const [showMyTournaments, setShowMyTournaments] = useState(false);
const [showMyTraining, setShowMyTraining] = useState(false);
```

#### 2. Modified API Calls to Include `mine` Filter

**Training Sessions API call** (line 163):

- Added `mine: showMyTraining` parameter to fetch only user-owned training sessions when the toggle is active
- When `showMyTraining` is true, only training sessions created by the current user are fetched

**Tournaments API call** (line 168):

- Added `mine: showMyTournaments` parameter to `fetchAllTournamentPages`
- When `showMyTournaments` is true, only tournaments created by the current user are fetched

#### 3. Added UI Toggle Component (lines 486-507)

Added a filter row above the `UpcomingAgenda` component with two checkboxes:

- **My Tournaments**: When checked, fetches only user-created tournaments
- **My Training**: When checked, fetches only user-owned training sessions

The toggles are implemented as HTML checkboxes that update the state variables on change.

### How It Works

The implementation leverages existing API `mine` parameters to distinguish between personal and shared content:

- When `showMyTournaments` is `false` (default): Shows all tournaments (shared + personal)
- When `showMyTournaments` is `true`: Shows only tournaments where `mine: true` is filtered
- When `showMyTraining` is `false` (default): Shows all training sessions
- When `showMyTraining` is `true`: Shows only training sessions where `mine: true` is filtered

### Build Status

- ✅ TypeScript compilation: Passes without errors
- ✅ Vite build: Completes successfully
- ✅ Development server: Running at http://localhost:5175/
