# Local Device Backend And Auth

## Root Cause

The Flutter client used to default to `http://localhost:3000`. On Android
emulators and physical Android/iOS devices, `localhost` does not mean the
development computer that runs Nest. Android emulators now default to
`http://10.0.2.2:3000`; physical phones must still use the computer LAN IPv4
address.

The backend now binds to `HOST=0.0.0.0`, and local mobile builds must point the
app at the computer's LAN IPv4 address.

## Run Backend For A Physical Phone

1. Find the computer IPv4 address on the same Wi-Fi network:

   ```powershell
   ipconfig
   ```

2. Keep `backend/.env` set to:

   ```env
   HOST=0.0.0.0
   PORT=3000
   CORS_ORIGINS=*
   ```

3. Start the API:

   ```powershell
   cd C:\dev\reem\backend
   npm run start
   ```

4. Check from the phone browser:

   ```text
   http://<computer-lan-ip>:3000/health
   ```

5. Run Flutter with the same base URL:

   ```powershell
   flutter run --dart-define=APP_ENV=local --dart-define=API_BASE_URL=http://<computer-lan-ip>:3000
   ```

For the Android emulator, the app defaults to `http://10.0.2.2:3000`, so this is
enough when the backend is running locally:

```powershell
flutter run --dart-define=APP_ENV=local
```

For production use HTTPS and pass the production API URL explicitly.

## OAuth Variables

The client obtains provider ID tokens and the backend verifies issuer,
signature, expiry, and audience.

Flutter build defines:

```text
GOOGLE_CLIENT_ID=<platform OAuth client id when required>
GOOGLE_SERVER_CLIENT_ID=<web/server OAuth client id used as ID-token audience>
APPLE_SERVICE_ID=<Apple Services ID for Android/web Apple Sign-In>
APPLE_REDIRECT_URI=<Apple configured return URL for Android/web Apple Sign-In>
```

Backend env:

```env
GOOGLE_CLIENT_IDS=<comma-separated accepted Google OAuth client IDs>
APPLE_CLIENT_IDS=<comma-separated accepted Apple bundle/service IDs>
```

Production must not rely on the backend development fallback
`provider_user_id`; production social auth requires a real `id_token`.

## Authentication Flow

- Guests land on Home after onboarding and may browse public commerce/community
  surfaces without being redirected to Login.
- Protected actions and protected routes show a sign-in prompt with Sign In,
  Create Account, and benefits instead of forcing an aggressive redirect.
- Login accepts either email or phone through the `identifier` request field.
  The backend still accepts legacy `phone` and explicit `email` fields.
- Remember Me stores the refresh token for long-lived session restoration.
  Turning it off keeps only the short-lived access token.
- Google and Apple login/linking now use native provider ID tokens. The backend
  verifies issuer, audience, expiry, and RSA signature before creating or
  linking a session.
