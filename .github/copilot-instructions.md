# HealthWallet Copilot Instructions

**HealthWallet** is a mobile health data aggregator transforming medical records into actionable lifestyle recommendations. Users upload blood work PDFs, and the app provides biomarker summaries with personalized wellness recommendations.

## Architecture Overview

### Tech Stack
- **iOS Frontend**: Swift 5.9+, SwiftUI, @Observable (iOS 17+)
- **Backend**: Hono (Bun runtime) + MongoDB
- **Auth**: JWT (jose library, 7-day expiry)
- **AI Integration**: Google Gemini 1.5 Flash + fallback regex parser
- **PDF Processing**: pdf-parse
- **Encryption**: bcrypt (passwords), AES-256-GCM (sensitive data)
- **Deployment**: Docker + Traefik on vibe-network (self-hosted, no cloud tax)

### Directory Structure
```
Healthwallet/
├── Healthwallet/              # iOS app (SwiftUI)
│   ├── Models/                # Swift data models (Biomarker, User, etc.)
│   ├── Views/                 # SwiftUI views organized by feature
│   ├── ViewModels/            # @Observable view models (business logic)
│   ├── Services/              # APIClient, AuthService, RecordsService
│   └── Theme/                 # Design system, colors, typography
├── backend/                   # Hono backend (Bun)
│   ├── src/
│   │   ├── index.ts           # App entry point, exports AppType for RPC
│   │   ├── config.ts          # Environment configuration
│   │   ├── db.ts              # MongoDB connection
│   │   ├── middleware/
│   │   ├── routes/            # API route handlers (auth, records, etc.)
│   │   ├── schemas/           # Zod validation schemas
│   │   └── services/          # Business logic (PDF processing, etc.)
│   ├── package.json           # Bun dependencies
│   └── docker-compose.yml
├── instructions.md            # Original project instructions
└── userflow.md                # User journey documentation
```

## Key Architectural Decisions

1. **Type-Safe End-to-End**: Zod schemas → Hono routes → RPC export to iOS
2. **No ORM/ODM Overhead**: Direct MongoDB driver for flexibility
3. **Single Language**: Full-stack TypeScript (Bun + Hono)
4. **Self-Hosted**: Docker + Traefik on vibe-network, no external cloud services
5. **Mobile-First**: Lightweight JSON responses, pagination for lists
6. **No Medical Claims**: All recommendations framed as "wellness optimization"

## Backend Development

### Running the Backend

**Development** (with hot reload):
```bash
cd backend
bun install
bun run --watch src/index.ts
```

**Production** (Docker):
```bash
cd backend
docker compose up -d
```

Server listens on `http://localhost:3000` (dev) or via Traefik (production).

### API Routes Structure

All routes are under `/api/v1`:
- `/auth/*` - Registration, login, profile management (auth.ts, auth-apple.ts)
- `/records/*` - PDF uploads, biomarker retrieval (records.ts)
- `/subscription/*` - RevenueCat integration, tier enforcement (subscription.ts)
- `/healthkit/*` - Apple HealthKit sync (healthkit.ts)
- `/telegram/*` - Telegram bot integration (telegram.ts)

### Adding New API Endpoints

1. **Define Zod schema** in `src/schemas/` (input/output validation)
2. **Create route handler** in `src/routes/` using `zValidator`
3. **Export AppType** from `src/index.ts` for Hono RPC
4. **iOS client** consumes via generated types

Example:
```typescript
// src/schemas/biomarker.ts
export const BiomarkerSchema = z.object({
  id: z.string(),
  value: z.number(),
  status: z.enum(["low", "optimal", "high"]),
});

// src/routes/records.ts
records.get("/dashboard", async (c) => {
  // Use authenticated user from middleware
  const user = c.get("user");
  // Return BiomarkerSchema compatible object
});
```

### Authentication Flow

1. **Registration/Login**: Returns JWT token (7-day expiry)
2. **Middleware** (`middleware/auth.ts`): Validates token, extracts user
3. **User Object**: Available via `c.get("user")` in authenticated routes
4. **Keychain Storage** (iOS): Token stored securely via Swift Keychain

## iOS Development

### SwiftUI Conventions

- **@Observable view models** (iOS 17+): All business logic, state management
- **Thin views**: UI only, no API calls or business logic in body
- **async/await**: All network operations (no .task modifier for API calls)
- **Simulator detection**: `#if targetEnvironment(simulator)` for API URL switching

### Services Layer

- **APIClient.swift**: Base HTTP client, token injection, error handling
- **AuthService.swift**: Register, login, profile, logout
- **RecordsService.swift**: Upload, fetch records, dashboard data

### Adding a New View Feature

1. Create Swift model in `Models/` (matching backend Zod schema)
2. Create `@Observable` view model in `ViewModels/`
3. Create SwiftUI view in `Views/YourFeature/`
4. Add service methods if API integration needed

## Subscription & Entitlements

### Tier System
- **Free**: 1 upload, basic dashboard (top 3 food recs, no supplements)
- **Pro**: Unlimited uploads, full recs, supplements, doctor brief, comparison
- **Backend Enforcement**: `User.subscription_tier`, `upload_count`, `can_upload` check on every upload
- **RevenueCat Webhook**: Updates tier on INITIAL_PURCHASE, RENEWAL, CANCELLATION, EXPIRATION

### User Model Fields
```typescript
{
  subscription_tier: "free" | "pro",
  upload_count: number,
  can_upload: boolean,
  revenue_cat_id?: string
}
```

## Business Logic

### Wellness Score Calculation
```
Start at 100
For each biomarker:
  - If status == "high": score -= 10
  - If status == "low": score -= 10
  - If status == "optimal": score += 0
Clamp to 0-100
```

### Biomarker Status Logic
```
If value < min_optimal: status = "low"
If value > max_optimal: status = "high"
Else: status = "optimal"
```

### Recommendation Mapping
Stored in database; keyed by biomarker ID + status. Example:
- `vitamin_d.low`: ["Add Salmon", "Morning Sun"]
- `ldl_cholesterol.high`: ["Reduce Red Meat", "Add Oatmeal"]

## Configuration & Secrets

Backend uses environment variables (see `backend/.env.example`):
- `MONGODB_URL`: MongoDB connection string
- `SECRET_KEY`: JWT signing secret
- `GOOGLE_API_KEY`: Gemini API key
- `REVENUECAT_API_KEY`: RevenueCat API access
- `DEBUG`: Set to "true" for synchronous processing (no background workers)

Load via `config.ts` with sensible defaults for development.

## Security Requirements

1. **JWT Expiry**: 7 days
2. **Password Hashing**: bcrypt (12+ rounds, compatible with legacy Python passwords)
3. **Sensitive Data Encryption**: AES-256-GCM for raw PDF text
4. **HTTPS Only**: Production deployments
5. **Keychain Storage** (iOS): Tokens stored securely, never in UserDefaults
6. **No Medical Claims**: Frame all recommendations as wellness optimization, not medical advice

## Common Workflows

### Debug a Route Issue
1. Check route definition in `src/routes/`
2. Verify Zod schema in `src/schemas/`
3. Check middleware (auth, CORS) in `src/index.ts`
4. Use `console.log()` (visible in bun terminal)

### Add Support for New Biomarker
1. Update Zod schema in `src/schemas/`
2. Add recommendation mapping to database
3. Update iOS model in `Models/`
4. Wire UI in `Views/BiomarkerDetail/`

### Verify Subscription Gate
1. Check `User.subscription_tier` in route handler
2. Validate with `if (user.subscription_tier !== "pro") return 403`
3. Test with free tier + pro tier accounts

## Notes

- **No external cloud services**: All infra self-hosted on Docker
- **Hono RPC**: Always export `AppType` from backend for type-safe iOS client
- **PDF Processing**: Async, may trigger background Gemini API calls
- **Pagination**: Use offset/limit pattern for list endpoints
- **Error Handling**: HTTPException for HTTP errors, JSON response format consistent
