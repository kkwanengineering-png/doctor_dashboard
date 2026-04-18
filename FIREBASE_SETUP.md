# Firebase Configuration Setup

This project uses Firebase. The configuration file `lib/firebase_options.dart` is
intentionally excluded from version control to protect API keys.

## First-time Setup

To run this project locally, you need to regenerate the Firebase config:

### Prerequisites
1. Install the Firebase CLI: `npm install -g firebase-tools`
2. Install the FlutterFire CLI: `dart pub global activate flutterfire_cli`
3. Ensure you have access to the `telerehab-a420e` Firebase project.

### Generate the Config
Run the following command from the project root:

```bash
firebase login
flutterfire configure --project=telerehab-a420e
```

This will regenerate `lib/firebase_options.dart` and `android/app/google-services.json`
automatically for your local environment.
