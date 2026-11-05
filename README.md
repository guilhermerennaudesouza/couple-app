# Krivo Couple App 💕

A private, unmetered, privacy-first Flutter application crafted exclusively for two partners. Built with modern Flutter (Material 3), Riverpod state management, and backed entirely by Firebase's free **Spark Tier** with offline disk persistence (100MB cache) and zero-knowledge encryption for intimate data.

---

## ✨ Features Overview

1. **Dual-Reveal Daily Connection** (`DailyQuestionScreen`):
   - A new intimacy prompt each day.
   - Both answers remain concealed until both partners have submitted, preventing bias and encouraging deep emotional intimacy.
   - History archive for revisiting cherished past reflections.
   - Quick action button on the app bar for instant access to Love Notes.

2. **Shared Tasks & Dynamic Checklists** (`TasksScreen`):
   - Chores and errands with due dates, assignees, and completion timestamps.
   - Reusable checklists for groceries, packing, date prep, and shared goals with real-time progress percentages.

3. **Shared Couple Calendar & Milestones** (`CalendarScreen`):
   - Annual anniversary countdowns with leap-year and DST resiliency.
   - Automated local notification reminders scheduled 3 days prior at 10:00 AM.
   - Categorized date nights, trips, birthdays, and doctor visits.

4. **Decide Together & Date Ideas** (`DecideScreen`):
   - Secret ballot voting ("This or That") for dinner, movies, and weekend trips.
   - Real-time match detection when both partners agree; animated coin-toss tie-breaker when votes split.
   - Curated romantic date bucket list with toggleable completed states.

5. **Love Notes & Sticky Wall** (`NotesScreen`):
   - Pastel-colored digital sticky notes pinned to a shared virtual board.
   - Live synchronization with home-screen Android Jetpack Glance widgets.

6. **Memories, Time Capsules & Wishlist** (`MemoriesScreen`):
   - Milestone photo timeline with romantic captions and locations.
   - Digital time capsules sealed until future anniversaries or special dates.
   - Mutual gift wishlist with price tracking, priority levels, and secret reservation toggles.

7. **Shared Finance & Savings Goals** (`FinanceScreen`):
   - 50/50 splits and custom proportional shares with automated net debt balancing (`calculateNetOwed`).
   - Shared piggy bank savings goals with milestone progress percentages.

8. **Zero-Knowledge Encrypted Private Vault & Romantic Cheatsheet** (`VaultScreen`):
   - Client-side AES-256-GCM encryption with keys derived via PBKDF2 (100,000 iterations, SHA-256) from a 6-digit PIN and couple salt.
   - Biometric unlock (`local_auth`) with secure keystore caching (`flutter_secure_storage`).
   - Partner romantic cheatsheet (ring size, shoe size, favorite flowers, coffee orders).
   - Absolute zero plaintext cloud storage.

9. **Android Jetpack Glance Home-Screen Widgets**:
   - `CoupleGlanceWidget`: Live couple countdown and anniversary milestone counter.
   - `DailyPromptGlanceWidget`: Daily prompt status pills across all 3 submission states.
   - `TasksGlanceWidget`: Top incomplete and urgent errands.
   - `NoteGlanceWidget`: Pinned love note with author signature.

---

## 🚀 Firebase Setup Guide (Spark Free Tier)

This app is engineered to operate 100% within Firebase's free **Spark Tier** without incurring costs.

### Step 1: Create a Firebase Project
1. Go to the [Firebase Console](https://console.firebase.google.com/).
2. Create a new project named e.g. `krivo-couple-app` (ensure the Spark pricing tier is selected).

### Step 2: Enable Anonymous Authentication
1. Navigate to **Authentication** > **Sign-in method**.
2. Enable the **Anonymous** sign-in provider.
3. The app automatically signs in anonymously upon first launch, generating a stable device UID without requiring phone numbers, emails, or passwords.

### Step 3: Enable Cloud Firestore
1. Navigate to **Firestore Database** > **Create database**.
2. Select **Production mode** and choose your preferred region.
3. Deploy the project security rules:
   ```bash
   firebase deploy --only firestore:rules
   ```
   *(Or copy the contents of `firestore.rules` directly into the Firestore Rules tab in the console).*

### Step 4: Storage & Photos (100% Free Spark Tier via Firestore)
- **No Cloud Storage bucket needed:** The app automatically compresses mobile camera photos to high-definition mobile resolution (1024px, 70% quality, ~80–120 KB) and stores them directly in Cloud Firestore as Base64 strings. This allows you to upload thousands of photos completely free forever on the Spark plan without linking a credit card.
- *(Optional)* If you ever upgrade to the pay-as-you-go Blaze plan to store raw uncompressed images in Google Cloud Storage, you can navigate to **Storage** > **Get started** and deploy `storage.rules`.

### Step 5: Register Android App & Add `google-services.json`
1. In Project Settings, click **Add app** and select **Android**.
2. Enter the Android package name:
   ```
   com.personal.couple_app
   ```
3. Enter an app nickname (e.g. `Krivo Couple App`).
4. Download the generated `google-services.json` configuration file.
5. Place the file at:
   ```
   android/app/google-services.json
   ```
   *(A reference template is available at `android/app/google-services.json.example`).*

---

## 🛠️ Development & Building

### Running the App
```bash
# Get dependencies
flutter pub get

# Run on connected Android device or emulator
flutter run
```

### Running Unit & End-to-End Tests
```bash
flutter test
```

### Building Release APK
The project is configured for arm64-v8a architecture and modern Samsung Galaxy devices (S22 Ultra, S24 Plus) with Proguard rules protecting Glance widgets and Flutter plugins:
```bash
flutter build apk --release
```
The output APK will be generated at:
```
build/app/outputs/flutter-apk/app-release.apk
```

---

## 🔐 Security & Privacy Architecture

- **Zero Cloud Plaintext**: Vault items are encrypted and decrypted purely in device RAM using AES-256-GCM.
- **Key Derivation**: 100,000 PBKDF2 iterations using HMAC-SHA256 and a deterministic couple salt (`krivo_vault_salt_<coupleId>`).
- **Strict Firestore Rules**: All 14 couple subcollections strictly enforce `isCoupleMember(coupleId)` authorization. Only authenticated members can read or write data.
- **Cryptographic PRNG**: 6-digit couple invite codes are generated using `Random.secure()`.
