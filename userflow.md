# HealthWallet — Complete App Architecture & User Flow

> **Health OS — Single Source of Truth for your body.**
> Three data pillars: Episodic (labs), Continuous (HealthKit), Subjective (mood logs).

---

## 1. App Launch & Authentication Flow

```mermaid
flowchart TD
    A[App Launch] --> B{AuthManager\nhas token?}
    B -->|No token| C[LoginView]
    B -->|Has token| D{Loading...}
    D -->|Token valid| E{needsOnboarding?}
    D -->|Token expired| C

    C --> F[Email + Password Login]
    C --> G[Apple Sign-In]
    C --> H[Register New Account]

    F -->|POST /auth/login| I{Auth Success?}
    G -->|POST /auth/apple| I
    H -->|POST /auth/register| I

    I -->|Yes| E
    I -->|No| C

    E -->|Yes| J[OnboardingView\n10-step chat flow]
    E -->|No| K[MainTabView]

    J --> J1[Step 1: Name]
    J1 --> J2[Step 2: Date of Birth]
    J2 --> J3[Step 3: Biological Sex]
    J3 --> J4[Step 4: Health Goals]
    J4 --> J5[Step 5: Dietary Preference]
    J5 --> J6[Step 6: Allergies]
    J6 --> J7[Step 7: Health Conditions]
    J7 --> J8[Step 8: Connect HealthKit]
    J8 --> J9[Step 9: Summary Review]
    J9 -->|POST /profile/onboarding| K

    style A fill:#e1f5fe
    style K fill:#c8e6c9
    style C fill:#fff3e0
    style J fill:#f3e5f5
```

---

## 2. Main Tab Navigation

```mermaid
flowchart LR
    MT[MainTabView] --> T0["Tab 0\nHome\nhouse.fill"]
    MT --> T1["Tab 1\nTrends\nchart.line"]
    MT --> T2["Tab 2\nJournal\nbook.fill"]
    MT --> T3["Tab 3\nChat\nbubble"]
    MT --> T4["Tab 4\nNutrition\nfork.knife"]
    MT --> T5["Tab 5\nProfile\nperson.fill"]

    T0 --> H[HomeView]
    T1 --> TR[ComparisonView\nYear-over-year trends]
    T2 --> JR[QuickLogHistoryView\nCalendar heat map + streak]
    T3 --> CH[ChatView\nGemini AI assistant]
    T4 --> NU[NutritionView\nFood recs + meal plan]
    T5 --> PR[ProfileView\nSettings + data mgmt]

    style MT fill:#e8eaf6
    style T0 fill:#c8e6c9
    style T3 fill:#f3e5f5
```

---

## 3. Home Screen State Machine

```mermaid
stateDiagram-v2
    [*] --> Loading: fetchRecords()

    Loading --> HasRecords: records.count > 0
    Loading --> EmptyState: records.isEmpty
    Loading --> SampleData: API error (fallback)

    state HasRecords {
        [*] --> CheckDailyLog
        CheckDailyLog --> ShowCheckIn: !todayLogged
        CheckDailyLog --> ShowStreak: todayLogged & streak > 0

        ShowCheckIn --> ShowStreak: user logs mood
        ShowStreak --> HealthKitCard: HK authorized
        HealthKitCard --> Dashboard
        ShowStreak --> Dashboard: HK not authorized

        state Dashboard {
            [*] --> WellnessScore
            WellnessScore --> BiomarkerSummary
            BiomarkerSummary --> WeeklyFocus
            WeeklyFocus --> RecordHistory
        }
    }

    state EmptyState {
        [*] --> DailyCheckIn
        DailyCheckIn --> ChatCTA: tap -> Tab 3
        DailyCheckIn --> UploadCTA: tap -> Upload sheet
        DailyCheckIn --> JournalCTA: tap -> Tab 2
    }
```

---

## 4. PDF Upload & Analysis Pipeline

```mermaid
flowchart TD
    U1[User taps + button] --> U2[UploadRecordView\nFile picker - PDF only]
    U2 --> U3[Select PDF file]
    U3 --> U4["Tap 'Analyze Record'"]
    U4 --> U5["POST /records/upload\n(multipart/form-data)"]

    U5 --> B1[Backend: Create HealthRecord\nstatus = UPLOADING]
    B1 --> B2[Save PDF to disk]
    B2 --> B3[Increment upload_count]
    B3 --> B4[processRecordAsync]

    B4 --> P1[Extract text from PDF\npdf-parse library]
    P1 --> P2[Encrypt raw text\nAES-256-GCM]
    P2 --> P3{AI Parser Available?}

    P3 -->|OpenRouter API| P4[Parse with Grok/GPT]
    P3 -->|Google API Key| P5[Parse with Gemini 1.5 Flash]
    P3 -->|No API key| P6[Regex fallback parser\n21 biomarker patterns]

    P4 --> P7[Extract biomarkers + correlations]
    P5 --> P7
    P6 --> P7

    P7 --> P8[detectCorrelations\n7 rule-based patterns]
    P8 --> P9[getSupplementProtocol\nPrioritized supplements]
    P9 --> P10[calculateWellnessScore\n30-100 range]
    P10 --> P11[calculateHealthAge\nAdjusted from DOB]
    P11 --> P12{Biomarkers found?}

    P12 -->|Yes| P13[Status: PENDING_REVIEW]
    P12 -->|No| P14[Status: FAILED]

    P13 --> V1[iOS polls GET /records/:id\nevery 3 seconds]
    V1 --> V2[RecordVerificationView\nHuman-in-the-loop]
    V2 --> V3["User reviews & approves\nPOST /records/:id/verify"]
    V3 --> V4[Status: COMPLETED]
    V4 --> V5[Refresh HomeView\nShow dashboard + insights]

    style U1 fill:#e3f2fd
    style V5 fill:#c8e6c9
    style P14 fill:#ffcdd2
```

---

## 5. Data Triangle Architecture

```mermaid
flowchart TD
    subgraph Episodic["Episodic Data (Labs/PDF)"]
        E1[PDF Upload] --> E2[AI Lab Parser]
        E2 --> E3[Biomarkers\nVitamin D, LDL, B12...]
        E3 --> E4[Correlations\nIron deficiency, Metabolic syndrome...]
        E4 --> E5[Supplement Protocol]
        E3 --> E6[Food Recommendations]
    end

    subgraph Continuous["Continuous Data (HealthKit)"]
        C1[Apple Health] --> C2[HealthKitManager]
        C2 --> C3[Steps, Sleep, HRV\nResting HR, Active Energy]
        C3 -->|POST /healthkit/sync| C4[daily_metrics collection]
    end

    subgraph Subjective["Subjective Data (Quick Logs)"]
        S1[Daily Check-In] --> S2[Mood 1-5]
        S1 --> S3[Energy 1-5]
        S1 --> S4[Symptoms]
        S1 --> S5[Notes]
        S2 -->|POST /logs/quick| S6[quick_logs collection]
    end

    E3 --> VS[Vitality Score\n0-100]
    C4 --> VS
    S6 --> VS

    VS --> D1[Home Dashboard]
    VS --> D2[AI Chat Context\nRAG with all data]
    VS --> D3[Nutrition Recommendations]
    VS --> D4[Weekly Focus Actions]

    style Episodic fill:#e8eaf6
    style Continuous fill:#e8f5e9
    style Subjective fill:#fff3e0
    style VS fill:#fce4ec
```

---

## 6. Weekly Focus Action Flow

```mermaid
flowchart TD
    BM[Flagged Biomarkers\n20+ supported] --> GEN[generateWeeklyFocus\nHomeViewModel]

    GEN --> R1["Vitamin D low\n-> Add Salmon (recipe)\n-> Morning Sun (reminder)"]
    GEN --> R2["LDL high\n-> Add Oatmeal (recipe)\n-> 30 Min Walk (reminder)"]
    GEN --> R3["B12 low\n-> Eggs & Dairy (recipe)\n-> B12 Supplement (reminder)"]
    GEN --> R4["Magnesium low\n-> Dark Chocolate (recipe)\n-> Mag Before Bed (reminder)"]
    GEN --> R5["...16 more biomarkers\n+ generic fallback"]

    R1 --> WFS[WeeklyFocusSection\nHorizontal scroll cards]
    R2 --> WFS
    R3 --> WFS
    R4 --> WFS
    R5 --> WFS

    WFS --> TAP{User taps\naction button}

    TAP -->|Set Reminder| CAL[CalendarManager\nEventKit 90-day recurring\nwith 5-min alert]
    TAP -->|See Recipe| CHAT[Navigate to Chat tab]
    TAP -->|Ask AI| CHAT
    TAP -->|Tips| TIP[Inline tip - no nav]

    CAL --> DONE["'Added!' feedback\nHaptic + green checkmark"]

    style BM fill:#e3f2fd
    style CAL fill:#fff3e0
    style CHAT fill:#f3e5f5
```

---

## 7. AI Chat System

```mermaid
flowchart TD
    UI[ChatView\nUser types message] -->|POST /chat| BE[Backend chat route]

    BE --> CTX[buildChatContext\nchat-context.ts]

    CTX --> CTX1[User Profile\nage, gender, diet, goals]
    CTX --> CTX2[Latest Biomarkers\nflagged + optimal]
    CTX --> CTX3[HealthKit 7-day avg\nsteps, sleep, HRV]
    CTX --> CTX4[Recent Mood Logs\nlast 5 entries]
    CTX --> CTX5[Supplement Protocol\ncurrent recommendations]

    CTX1 --> SYS[System Prompt\nMobile-first: 1-3 sentences\nNo headers, conversational]
    CTX2 --> SYS
    CTX3 --> SYS
    CTX4 --> SYS
    CTX5 --> SYS

    SYS --> AI{AI Provider}
    AI -->|Primary| OR[OpenRouter\nGrok/GPT - 300 tokens]
    AI -->|Fallback| GEM[Google Gemini\n2.0 Flash - 300 tokens]

    OR --> RESP[Short chat response\n1-3 sentences]
    GEM --> RESP

    RESP -->|Save to MongoDB| DB[(messages collection)]
    RESP --> UI2[MessageBubble\nMarkdown rendered]

    style UI fill:#e3f2fd
    style RESP fill:#c8e6c9
    style SYS fill:#fff3e0
```

---

## 8. Backend API Map

```mermaid
flowchart LR
    subgraph Auth["/api/v1/auth"]
        A1[POST /register]
        A2[POST /login]
        A3[POST /apple]
        A4[GET /me]
        A5[PATCH /me]
    end

    subgraph Records["/api/v1/records"]
        R1[POST /upload]
        R2[GET /]
        R3[GET /:id]
        R4[POST /:id/verify]
        R5[GET /dashboard/summary]
        R6[GET /comparison]
        R7[POST /export/doctor-brief]
    end

    subgraph Health["/api/v1/healthkit"]
        H1[POST /sync]
        H2[GET /summary]
        H3[GET /today]
        H4[GET /vitality]
    end

    subgraph Logs["/api/v1/logs"]
        L1[POST /quick]
        L2[GET /quick]
        L3[GET /quick/streak]
        L4[GET /quick/calendar]
    end

    subgraph Chat["/api/v1/chat"]
        C1[POST /]
        C2[GET /history]
        C3[GET /suggestions]
    end

    subgraph Nutrition["/api/v1/nutrition"]
        N1[GET /recommendations]
        N2[GET /meal-plan]
    end

    subgraph Profile["/api/v1/profile"]
        P1[GET /]
        P2[PUT /]
        P3[POST /onboarding]
    end

    subgraph Monetization["/api/v1"]
        M1[GET /subscription/status]
        M2[POST /subscription/verify-receipt]
        M3[POST /subscription/webhooks/revenuecat]
        M4[POST /webhooks/churnkey]
        M5[GET /affiliate/recommendations/latest]
    end

    subgraph Telegram["/api/v1/telegram"]
        T1[POST /webhook]
    end

    JWT[JWT Middleware\nHS256 via jose] --> Records
    JWT --> Health
    JWT --> Logs
    JWT --> Chat
    JWT --> Nutrition
    JWT --> Profile

    style Auth fill:#e8eaf6
    style Records fill:#e3f2fd
    style Health fill:#e8f5e9
    style Logs fill:#fff3e0
    style Chat fill:#f3e5f5
    style Nutrition fill:#fce4ec
    style Monetization fill:#f1f8e9
```

---

## 9. Subscription & Monetization Flow

```mermaid
flowchart TD
    FREE[Free User] --> GATE{Feature Gate}

    GATE -->|1 upload limit| UL[Upload blocked\nShow paywall]
    GATE -->|Top 3 food recs only| BASIC[Basic dashboard]
    GATE -->|No supplements| NOSUP[Supplements locked]
    GATE -->|No doctor brief| NOBRIEF[Export locked]
    GATE -->|No comparison| NOCOMP[Trends locked]

    UL --> PW[PaywallView\nRevenueCat]
    NOSUP --> PW
    NOBRIEF --> PW
    NOCOMP --> PW

    PW --> RC[RevenueCat Purchase\n$5.99/mo]
    RC -->|Webhook| WH[POST /subscription/webhooks/revenuecat]
    WH --> DB[Update user.subscription_tier = pro]
    DB --> PRO[Pro User\nUnlimited uploads\nFull recommendations\nDoctor brief\nComparison view]

    PRO --> CANCEL{User cancels?}
    CANCEL -->|Yes| CK[Churnkey Flow\nPOST /webhooks/churnkey]
    CK --> OFFER[Retention offer\n90-day cooldown per offer type]
    OFFER -->|Accepted| PRO
    OFFER -->|Declined| FREE

    style FREE fill:#fff3e0
    style PRO fill:#c8e6c9
    style PW fill:#e8eaf6
```

---

## 10. Nutrition Engine Flow

```mermaid
flowchart TD
    BIO[Flagged Biomarkers] --> NE[analyzeNutrientNeeds\nnutrient-mapping.ts]

    NE --> NR1["Vitamin D low -> Vitamin D foods"]
    NE --> NR2["Iron low -> Iron + Vitamin C foods"]
    NE --> NR3["LDL high -> Omega-3 + Fiber foods"]
    NE --> NR4["B12 low -> B12-rich foods"]
    NE --> NR5["...13+ biomarker rules"]

    NR1 --> DIET{filterByDiet}
    NR2 --> DIET
    NR3 --> DIET
    NR4 --> DIET
    NR5 --> DIET

    DIET -->|Omnivore| D1[Salmon, Eggs, Beef...]
    DIET -->|Vegetarian| D2[Eggs, Fortified Milk...]
    DIET -->|Vegan| D3[Mushrooms, Fortified Oat...]
    DIET -->|Keto| D4[Salmon, Egg Yolks...]

    D1 --> VIEW[NutritionView]
    D2 --> VIEW
    D3 --> VIEW
    D4 --> VIEW

    VIEW --> SEG{Segment Picker}
    SEG -->|Foods| FOODS[Food cards\nwith nutrients & reasons]
    SEG -->|Meal Plan| MP[generateMealPlan\n7-day plan\nBreakfast/Lunch/Dinner/Snack]

    style BIO fill:#e3f2fd
    style VIEW fill:#c8e6c9
```

---

## 11. Telegram Bot Integration

```mermaid
flowchart TD
    APP[iOS App\nProfile -> Link Telegram] --> DL[Deep Link\nAES-256-GCM encrypted user_id\n10-min expiry]

    DL --> TG[Telegram Bot\n/start deep_link_payload]
    TG --> DECRYPT[Decrypt & validate\nLink telegram_id to user]

    DECRYPT --> LINKED[Account linked]

    LINKED --> CMD1["/today -> Daily health summary"]
    LINKED --> CMD2["/log -> Quick mood entry"]
    LINKED --> CMD3["/unlink -> Remove link"]

    SCHED[Daily Digest Scheduler\n08:00 UTC] --> DIGEST[Send summary to all\nlinked Telegram users]

    style APP fill:#e3f2fd
    style TG fill:#e8eaf6
    style SCHED fill:#fff3e0
```

---

## 12. Complete Data Model

```mermaid
erDiagram
    USERS {
        ObjectId _id
        string email
        string password_hash
        string name
        date date_of_birth
        string gender
        string auth_provider "email | apple"
        string apple_id
        string subscription_tier "free | pro"
        date subscription_expires_at
        string revenuecat_id
        int upload_count
        string dietary_preference
        string[] allergies
        string[] health_goals
        string[] health_conditions
        string telegram_id
        date telegram_linked_at
        boolean needs_onboarding
    }

    HEALTH_RECORDS {
        ObjectId _id
        ObjectId user_id
        string status "uploading | processing | pending_review | completed | failed"
        date record_date
        string file_path
        string raw_text_encrypted
        json[] biomarkers
        json[] correlations
        json[] food_recommendations
        json[] supplement_protocol
        int wellness_score
        int health_age
        string summary
    }

    DAILY_METRICS {
        ObjectId _id
        string user_id
        string date "YYYY-MM-DD"
        int steps
        float sleep_hours
        float hrv_avg
        float resting_heart_rate
        float active_energy_kcal
    }

    QUICK_LOGS {
        ObjectId _id
        string user_id
        string date "YYYY-MM-DD"
        int mood "1-5"
        int energy "1-5"
        string[] symptoms
        string notes
    }

    MESSAGES {
        ObjectId _id
        string user_id
        string role "user | assistant"
        string content
        date created_at
    }

    CHURN_EVENTS {
        ObjectId _id
        string user_id
        string reason
        string offer_shown
        boolean deflected
        date created_at
    }

    USERS ||--o{ HEALTH_RECORDS : uploads
    USERS ||--o{ DAILY_METRICS : syncs
    USERS ||--o{ QUICK_LOGS : logs
    USERS ||--o{ MESSAGES : chats
    USERS ||--o{ CHURN_EVENTS : churns
```

---

## 13. Infrastructure

```mermaid
flowchart LR
    subgraph Client
        IOS["iOS App\nSwiftUI\nXcode 16"]
    end

    subgraph VPS["$6/mo VPS (Docker)"]
        TRAEFIK[Traefik\nReverse Proxy\nAuto SSL/HTTPS]
        HONO["Hono Backend\nBun Runtime\nPort 8000"]
        MONGO[(MongoDB\nvibe-network)]
    end

    subgraph External
        RC[RevenueCat\nSubscriptions]
        GEM[Gemini / OpenRouter\nAI Chat + Lab Parser]
        APL[Apple JWKS\nSign-In verification]
        TG_API[Telegram Bot API\nGrammy framework]
    end

    IOS -->|HTTPS| TRAEFIK
    TRAEFIK --> HONO
    HONO --> MONGO
    HONO --> GEM
    HONO --> APL
    HONO --> TG_API
    IOS --> RC

    style VPS fill:#e8f5e9
    style External fill:#fff3e0
```

---

## Tech Stack Summary

| Layer | Technology |
|-------|-----------|
| iOS | Swift 5.9+, SwiftUI, @Observable, HealthKit, EventKit |
| Backend | Hono (TypeScript) on Bun runtime |
| Database | MongoDB (Docker, vibe-network) |
| AI | Gemini 2.0 Flash / OpenRouter (Grok) |
| Auth | JWT (jose, HS256), Apple Sign-In (JWKS), bcrypt |
| Encryption | AES-256-GCM (Web Crypto API) |
| Payments | RevenueCat + Churnkey |
| Infra | Docker + Traefik, self-hosted VPS |
| Bot | Telegram via Grammy, webhook mode |
| PDF | pdf-parse + AI/regex extraction |
