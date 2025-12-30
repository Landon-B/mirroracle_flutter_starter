# Mirroracle Flutter + Supabase Starter

Minimal starter to sign up/in and write a session row to Supabase.

## 1) Install Flutter (macOS)

```bash
brew install --cask flutter
flutter doctor
# iOS: install Xcode, then:
sudo gem install cocoapods
# Android (optional):
# brew install --cask android-studio
# flutter doctor --android-licenses
```

## 2) Create Supabase project

1. https://supabase.com → New project.
2. Copy **Project URL** and **anon public key**.
3. SQL editor → paste `supabase_setup.sql` and run.
4. Auth → turn off email confirmations for now (optional) to simplify sign-up.

## 3) Configure the app

Edit `lib/secrets.dart`:

```dart
const String SUPABASE_URL = 'https://YOUR-REF.supabase.co';
const String SUPABASE_ANON_KEY = 'YOUR_ANON_KEY';
```

## 4) Run

```bash
flutter pub get
open -a Simulator   # iOS
flutter run -d ios
```

Sign up with email+password, then tap **Complete Dummy Session** to insert into `sessions`.

## Next
- Wire real session-complete flow.
- Add Moments storage bucket + RLS when you need media uploads.
- Add push notifications.
