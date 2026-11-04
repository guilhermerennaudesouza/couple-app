# Design Document: Private Couple App (Krivo Clone with Firebase)

**Date**: 2026-11-04  
**Author**: Antigravity & User  
**Status**: Ready for Approval  

---

## 1. Intent & The Why

Build a private, self-contained, and completely unmetered Android application for two partners (Samsung Galaxy S22 Ultra and S24 Plus) that replicates the complete feature set of the Krivo couples app. The application operates strictly within Google Firebase's free **Spark plan** ($0 forever, no credit card required) for real-time bidirectional synchronization, offline persistence, and media storage. All commercial monetization mechanisms (paywalls, subscription gates, quotas, telemetry, and advertising) are completely eliminated.

---

## 2. Goals, Non-Goals, and Anti-Goals

### Goals
* **Full Feature Parity**: Daily prompts (with 20:00 local reminder), shared tasks, interactive lists, live sticky notes, shared calendar/anniversaries, date ideas ("Do Together"), decision maker ("Decide Together"), photo memories album, time capsules, gift radar/wishlist, partner cheatsheet, love coupons, shared finance/splits, savings piggy bank, biometric/PIN private vault, and adult card games (18+).
* **Target Hardware**: Tailored specifically for modern flagship Android devices (Samsung One UI, Android 14/15, S22 Ultra & S24 Plus).
* **Direct Real-Time Sync**: Sub-second synchronization of shared lists, tasks, notes, and ballot votes using Cloud Firestore live listeners (`snapshots()`).
* **Offline-First Capabilities**: Read and write operations succeed offline; changes automatically flush and resolve conflicts when reconnecting.
* **Home Screen Widgets**: Native Android Jetpack Glance widgets for couple countdown, pinned sticky note, daily prompt status, and high-priority tasks.
* **Strict $0 Cost**: Operates entirely within the free Firebase Spark plan without requiring a credit card or billing account.

### Non-Goals
* **No iOS / Web Builds**: Dedicated Android-first codebase; no iOS provisioning or WidgetKit maintenance.
* **No Multi-Tenancy or Public User Management**: Strictly scoped to the two partners via a single shared `coupleId`.
* **No Legacy Data Migration**: Clean initial deployment with pre-seeded question and date idea decks.

### Anti-Goals
* **No Paid Cloud Infrastructure**: No Firebase Blaze plan, no Cloud Functions, no VPS hosting, and no third-party paid APIs.
* **No In-App Purchases or Ad SDKs**: No RevenueCat, Google Play Billing, or tracking libraries.

---

## 3. Approaches Considered & Selected

### Approach 1: Flutter + Direct Cloud Firestore + Firebase Storage *(Selected)*
* **Architecture**: Flutter Android app utilizing Riverpod for reactive state management, GoRouter for declarative routing, and direct Cloud Firestore SDK with local disk persistence. Shared images stored in Firebase Storage. Scheduled notifications handled on-device via `flutter_local_notifications`.
* **Trade-offs**: Fast development cycle, zero server maintenance, built-in offline caching, and completely free on the Spark tier.
* **Why Selected**: Directly fulfills all user requirements without introducing unnecessary backend complexity.

### Approach 2: Flutter + Local SQLite (Drift) + Custom Sync Queue
* **Trade-offs**: High complexity in writing conflict resolution, data schemas, and synchronization workers when Firestore already handles this natively.

### Approach 3: React Native (Expo)
* **Trade-offs**: Weaker native Android widget (Glance) ecosystem compared to Flutter's `home_widget` package.

---

## 4. System Architecture & Component Design

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter Android Client                   │
│   (Riverpod 2.x • GoRouter • Material 3 • Flutter Animate)   │
└──────────────┬──────────────────────────────┬───────────────┘
               │                              │
┌──────────────▼──────────────┐ ┌─────────────▼───────────────┐
│     Jetpack Glance Widgets  │ │      Local Vault Crypto     │
│   (home_widget • One UI)    │ │ (AES-256-GCM • Biometrics)  │
└──────────────┬──────────────┘ └─────────────┬───────────────┘
               │                              │
┌──────────────▼──────────────────────────────▼───────────────┐
│                  Firebase Free Spark Tier                   │
│  • Cloud Firestore (Offline Disk Cache + Live WebSockets)   │
│  • Firebase Cloud Storage (Photos, Vault Media, Avatars)    │
│  • Firebase Auth (Google Sign-In / Passwordless Email OTP)  │
│  • flutter_local_notifications (Local Scheduled Alarms)    │
└─────────────────────────────────────────────────────────────┘
```

### 4.1. Authentication & Pairing
1. **Auth**: Firebase Authentication via Google Sign-In or Passwordless Email OTP.
2. **Setup**: 
   * Partner 1 creates the couple profile, generating a 6-digit pairing code stored in `/couples/{coupleId}` with `members: [uid1]`.
   * Partner 2 enters the code or scans the QR code; the app appends `uid2` to `members`.
   * Both devices cache `coupleId` in encrypted local preferences (`flutter_secure_storage`).

---

## 5. Cloud Firestore Data Schema

All collections reside under the isolated path `/couples/{coupleId}/`:

```
/couples/{coupleId}
  ├── members: [uid1, uid2]
  ├── anniversaryDate: Timestamp
  ├── partnerProfiles: { uid1: { name, avatarUrl }, uid2: { name, avatarUrl } }
  │
  ├── /daily_questions/{questionId}
  │     ├── date: "YYYY-MM-DD", prompt: string
  │     ├── answers: { [uid]: { text: string, answeredAt: Timestamp } }
  │     └── revealed: boolean (true when both answer or 24h elapses)
  │
  ├── /tasks/{taskId}
  │     └── title, description, assignedTo (uid), dueDate, isCompleted, completedAt
  │
  ├── /lists/{listId}
  │     └── title, category, items: [{ id, text, isDone, addedBy }]
  │
  ├── /notes/{noteId}
  │     └── title, content, colorHex, isPinnedToWidget: boolean, updatedAt
  │
  ├── /calendar_events/{eventId}
  │     └── title, date: Timestamp, isAnnual: boolean, category, reminderDaysBefore
  │
  ├── /decide_sessions/{sessionId}
  │     └── title, options: [string], votes: { [uid]: selectedOption }, status: "open"|"closed"
  │
  ├── /date_ideas/{ideaId}
  │     └── title, description, category, isCompleted: boolean, isWeeklyPick: boolean
  │
  ├── /memories/{memoryId}
  │     └── title, date: Timestamp, caption, photoUrls: [string]
  │
  ├── /time_capsules/{capsuleId}
  │     └── title, unlockDate: Timestamp, photoUrls: [string], message: string, isOpened: boolean
  │
  ├── /partner_cheatsheet/{uid}
  │     └── clothingSize, shoeSize, ringSize, coffeeOrder, allergies, comfortFood, notes
  │
  ├── /loyalty_coupons/{couponId}
  │     └── title, description, totalUses: int, usedCount: int, redeemedAt: [Timestamp]
  │
  ├── /finance_entries/{entryId}
  │     └── title, amount: double, category, paidByUid, splitType: "50-50"|"custom", date
  │
  ├── /savings_goals/{goalId}
  │     └── title, targetAmount: double, currentAmount: double, targetDate, contributions: [{ uid, amount, date }]
  │
  ├── /vault_items/{itemId}
  │     └── encryptedPayload: string (AES-256-GCM), iv: string, title, type, updatedAt
  │
  ├── /cycle_data/{cycleId}
  │     └── encryptedPayload: string, startDate, endDate, partnerConsentGiven: boolean
  │
  └── /adult_games/{gameId}
        └── deckName, cardsDrawn: [int], customPrompts: [string], is18Confirmed: { [uid]: boolean }
```

---

## 6. Security, Encryption & Privacy Rules

### 6.1. Firestore Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isCoupleMember(coupleId) {
      return request.auth != null &&
        request.auth.uid in get(/databases/$(database)/documents/couples/$(coupleId)).data.members;
    }

    match /couples/{coupleId} {
      allow read, update: if request.auth != null && request.auth.uid in resource.data.members;
      allow create: if request.auth != null;

      match /{subcollection}/{document=**} {
        allow read, write: if isCoupleMember(coupleId);
      }
    }
  }
}
```

### 6.2. Vault & Health Encryption
* **Vault Cryptography**: End-to-end encrypted with **AES-256-GCM**.
* **Key Derivation**: Both partners establish a shared 6-digit master PIN. The PIN is combined with a couple-specific salt and derived using **PBKDF2** into a 256-bit symmetric key.
* **Biometric Convenience**: Once derived, the symmetric key is stored in the Android Keystore (`flutter_secure_storage`) gated by biometric fingerprint authentication (`local_auth`) on each device.

---

## 7. Notifications & Widget Mechanics (Spark Tier Compliant)

* **Local Scheduled Reminders**:
  * Using `flutter_local_notifications`, the app schedules exact on-device alarms for:
    * **Daily Question Prompt**: Fixed at 20:00 (8:00 PM) daily.
    * **Calendar Anniversaries**: Scheduled N days in advance.
    * **Task Due Dates**: Scheduled for task expiration.
* **Real-Time Partner Awareness**:
  * Because Spark tier precludes Cloud Functions for push pings when the app is terminated, live Firestore listeners trigger animated snackbars, visual badge counts, and celebratory banners whenever the partner performs an action while the app is active or opened.
* **Home Screen Widgets (`home_widget`)**:
  * Built using **Jetpack Glance** (modern Kotlin Compose for Android widgets).
  * Widgets read cached data from Android `SharedPreferences`, which Flutter continuously updates whenever a Firestore snapshot stream fires:
    1. **Couple Counter Widget**: Days together, relationship anniversary countdown, and partner profile badge.
    2. **Sticky Note Widget**: Live partner note with customizable pastel background.
    3. **Daily Prompt Widget**: Today's prompt question and status ("Waiting for partner" vs "Answer ready!").
    4. **Top Tasks Widget**: Immediate shared grocery/to-do checklist with direct interactive checkboxes.

---

## 8. What is Left to the Builder

* Material 3 color themes (dynamic Material You palette harmonizing with Samsung One UI).
* Extraction of Krivo's default question and card prompt JSON files for local offline seeding.
* Confetti and haptic feedback celebrations when shared tasks or date ideas are marked completed.
