# HealthWallet - Project Instructions

## Project Overview

**HealthWallet** is a mobile health data aggregator that transforms complex medical records into actionable lifestyle recommendations. The app focuses on "translation" rather than storage - helping users understand their health data and take immediate action.

---

## Architecture

### Tech Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| **iOS App** | Swift/SwiftUI | Native iOS user interface |
| **Backend** | FastAPI (Python 3.11+) | REST API & business logic |
| **Database** | MongoDB (Atlas) | Document storage |
| **ODM** | Beanie | Async MongoDB models |
| **Auth** | JWT (OAuth2) | Token-based authentication |
| **AI** | Google Gemini | Biomarker extraction from PDFs |
| **Tasks** | Celery + Redis | Background PDF processing |
| **Encryption** | Fernet | Field-level data encryption |

### Project Structure

```
Healthwallet/
├── Healthwallet/                 # iOS App (SwiftUI)
│   ├── HealthwalletApp.swift     # App entry point
│   ├── ContentView.swift         # Root view
│   ├── Models/                   # Data models
│   │   ├── Biomarker.swift
│   │   ├── HealthRecord.swift
│   │   ├── BiomarkerStatus.swift
│   │   └── WeeklyFocus.swift
│   ├── Views/                    # UI screens
│   │   ├── MainTabView.swift
│   │   ├── Home/
│   │   ├── Upload/
│   │   ├── Profile/
│   │   ├── BiomarkerDetail/
│   │   └── Welcome/
│   ├── ViewModels/               # Business logic
│   │   ├── HomeViewModel.swift
│   │   └── BiomarkerDetailViewModel.swift
│   ├── Theme/                    # Design system
│   │   └── AppTheme.swift
│   └── Services/                 # API integration (TO ADD)
│       ├── APIClient.swift
│       ├── AuthService.swift
│       └── RecordsService.swift
│
├── backend/                      # FastAPI Backend
│   ├── app/
│   │   ├── main.py              # FastAPI app
│   │   ├── config.py            # Environment settings
│   │   ├── database.py          # MongoDB connection
│   │   ├── models/              # Beanie documents
│   │   │   ├── user.py
│   │   │   └── health_record.py
│   │   ├── schemas/             # Pydantic models
│   │   │   ├── auth.py
│   │   │   └── records.py
│   │   ├── api/v1/              # API routes
│   │   │   ├── auth.py
│   │   │   └── records.py
│   │   ├── security/            # Auth & encryption
│   │   │   ├── auth.py
│   │   │   ├── password.py
│   │   │   └── encryption.py
│   │   ├── services/            # Business logic
│   │   │   ├── pdf_processor.py
│   │   │   └── claude_parser.py
│   │   └── tasks/               # Background jobs
│   │       ├── celery_app.py
│   │       └── process_record.py
│   ├── requirements.txt
│   └── .env.example
│
├── userflow.md                   # User journey documentation
├── instructions.md               # This file
└── .claude/                      # Claude Code settings
    └── settings.json
```

---

## Coding Standards

### Swift/iOS

```swift
// Use @Observable for view models (iOS 17+)
@Observable
class HomeViewModel {
    var records: [HealthRecord] = []
    var isLoading = false

    func fetchDashboard() async throws {
        isLoading = true
        defer { isLoading = false }
        // API call
    }
}

// Use async/await for all network calls
func uploadRecord(_ file: URL) async throws -> HealthRecord {
    let data = try Data(contentsOf: file)
    return try await APIClient.shared.upload(data)
}

// Keep views thin - logic in ViewModels
struct HomeView: View {
    @State private var viewModel = HomeViewModel()

    var body: some View {
        // UI only, no business logic
    }
}
```

### Python/FastAPI

```python
# Async first - all I/O operations
async def get_user_records(user_id: str) -> list[HealthRecord]:
    return await HealthRecord.find(
        HealthRecord.user_id == user_id
    ).to_list()

# Pydantic for all request/response
class BiomarkerResponse(BaseModel):
    id: str
    title: str
    value: float
    unit: str
    status: Literal["low", "optimal", "high"]

# Dependency injection for auth
@router.get("/dashboard")
async def get_dashboard(
    user: User = Depends(get_current_user)
) -> DashboardResponse:
    ...
```

---

## API Contract

### Authentication

```
POST /api/v1/auth/register
Body: { "email": "...", "password": "...", "full_name": "..." }
Response: { "id": "...", "email": "...", "full_name": "..." }

POST /api/v1/auth/login
Body: { "username": "...", "password": "..." }
Response: { "access_token": "...", "token_type": "bearer" }

GET /api/v1/auth/me
Headers: Authorization: Bearer <token>
Response: { "id": "...", "email": "...", "full_name": "..." }
```

### Records

```
POST /api/v1/records/upload
Headers: Authorization: Bearer <token>
Body: multipart/form-data (file)
Response: { "id": "...", "status": "processing" } (HTTP 202)

GET /api/v1/records/{id}
Response: { "id": "...", "status": "completed", "biomarkers": [...] }

GET /api/v1/records
Response: { "records": [...], "total": 10, "page": 1 }
```

### Dashboard (TO IMPLEMENT)

```
GET /api/v1/dashboard
Response:
{
  "wellness_score": 84,
  "score_breakdown": { "metabolic": 92, "hormonal": 78 },
  "biomarker_trends": [
    {
      "id": "vitamin_d",
      "title": "Vitamin D",
      "value": 24,
      "unit": "ng/mL",
      "status": "low",
      "trend_points": [20, 22, 24]
    }
  ],
  "action_plan": [
    {
      "id": "1",
      "title": "Add Salmon",
      "subtitle": "Omega-3 boost",
      "is_completed": false,
      "type": "recipe"
    }
  ]
}
```

---

## Environment Setup

### Backend

```bash
cd backend
python -m venv venv
source venv/bin/activate  # or `venv\Scripts\activate` on Windows
pip install -r requirements.txt

# Create .env file
cp .env.example .env
# Edit .env with your values:
# - MONGODB_URL
# - SECRET_KEY
# - GOOGLE_API_KEY (for Gemini)
# - REDIS_URL (for Celery)

# Run server
uvicorn app.main:app --reload

# Run Celery worker (separate terminal)
celery -A app.tasks.celery_app worker --loglevel=info
```

### iOS App

```bash
# Open in Xcode
open Healthwallet.xcodeproj

# Or use xcodebuild
xcodebuild -scheme Healthwallet -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

---

## Implementation Priorities

### Phase 1: Backend Integration (Current)
1. [x] Backend exists with auth, upload, parsing
2. [ ] Move backend to `/backend/` folder
3. [ ] Add iOS networking layer (APIClient)
4. [ ] Implement auth flow in iOS
5. [ ] Connect upload to real backend
6. [ ] Wire dashboard to API response

### Phase 2: Dashboard Enhancement
1. [ ] Add `GET /dashboard` endpoint
2. [ ] Implement wellness score calculation
3. [ ] Add trend tracking (historical data)
4. [ ] Implement action item completion

### Phase 3: Polish
1. [ ] Error handling & offline support
2. [ ] Loading states & animations
3. [ ] Push notifications for processing complete
4. [ ] App Store preparation

---

## Security Requirements

1. **JWT tokens** expire in 7 days
2. **Passwords** hashed with bcrypt (min 12 rounds)
3. **Sensitive data** (raw PDF text) encrypted with Fernet
4. **HTTPS only** in production
5. **No medical claims** - all recommendations framed as "wellness optimization"

---

## Key Business Rules

### Wellness Score Calculation
```
Start at 100
For each biomarker:
  - If status == "high": score -= 10
  - If status == "low": score -= 10
  - If status == "optimal": score += 0
Clamp result to 0-100
```

### Biomarker Status Logic
```
Given: value, min_optimal, max_optimal

If value < min_optimal:
  status = "low"
Else if value > max_optimal:
  status = "high"
Else:
  status = "optimal"
```

### Recommendation Mapping
```python
RECOMMENDATIONS = {
    "vitamin_d": {
        "low": [
            {"title": "Add Salmon", "type": "recipe"},
            {"title": "Morning Sun", "type": "habit"}
        ]
    },
    "ldl_cholesterol": {
        "high": [
            {"title": "Reduce Red Meat", "type": "food"},
            {"title": "Add Oatmeal", "type": "recipe"}
        ]
    }
}
```

---

## Testing

### Backend
```bash
pytest tests/ -v
```

### iOS
- Unit tests in `HealthwalletTests/`
- UI tests in `HealthwalletUITests/`

---

## Deployment

### Backend
- **Development**: `uvicorn app.main:app --reload`
- **Production**: Docker → Railway/Render/Fly.io
- **Database**: MongoDB Atlas (free tier available)

### iOS
- TestFlight for beta testing
- App Store Connect for release
