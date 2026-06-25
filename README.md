# Z Mobile

Flutter client for local Z development.

## Local Setup

```bash
cp .env.example .env
flutter pub get
flutter run
```

Run the backend first and confirm it is reachable:

```bash
cd ../z-backend
make dev
curl http://localhost:3000/api/v1/health
```

The backend binds to `0.0.0.0`, so physical devices can reach it through the
Mac LAN IP when the Mac firewall and Wi-Fi network allow it.

## API Base URL

iOS Simulator can use the Mac loopback address:

```bash
flutter run -d "iPhone 17 Pro" --dart-define=API_BASE_URL=http://localhost:3000
```

Android Emulator must use the Android host alias:

```bash
flutter run -d <ANDROID_EMULATOR_ID> --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

A real iPhone connected by cable or Wi-Fi cannot use `localhost` to reach the
Mac backend. Use the Mac LAN IP:

```env
APP_ENV=development
API_BASE_URL=http://<MAC_LOCAL_IP>:3000
```

```bash
flutter run -d <IPHONE_DEVICE_ID> --dart-define=API_BASE_URL=http://<MAC_LOCAL_IP>:3000
```

Before testing login on a real iPhone, open Safari on the iPhone:

```text
http://<MAC_LOCAL_IP>:3000/api/v1/health
```

If `API_BASE_URL` is omitted, development builds fall back automatically:

- Android Emulator: `http://10.0.2.2:3000`
- iOS Simulator: `http://localhost:3000`
- Physical devices: `API_LAN_IP=<MAC_LOCAL_IP>`

Login and register requests have a 10 second connection timeout and 20 second
send/receive timeouts. If the backend is unreachable, the app shows:

```text
Impossible de joindre le serveur. Vérifiez l’adresse API et le backend.
```
