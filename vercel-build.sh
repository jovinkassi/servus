#!/bin/bash
# Install Flutter SDK
echo "Installing Flutter..."
git clone https://github.com/flutter/flutter.git --depth 1 -b stable /tmp/flutter
export PATH="$PATH:/tmp/flutter/bin"
flutter --version

# Build Flutter web
echo "Building Flutter web..."
flutter build web --release

# Generate env.js from Vercel environment variables
echo "Generating env.js..."
cat > build/web/env.js << ENVEOF
window.ENV = {
  GOOGLE_MAPS_API_KEY: '${GOOGLE_MAPS_API_KEY}',
  FIREBASE_API_KEY: '${FIREBASE_API_KEY}',
  FIREBASE_AUTH_DOMAIN: '${FIREBASE_AUTH_DOMAIN}',
  FIREBASE_PROJECT_ID: '${FIREBASE_PROJECT_ID}',
  FIREBASE_STORAGE_BUCKET: '${FIREBASE_STORAGE_BUCKET}',
  FIREBASE_MESSAGING_SENDER_ID: '${FIREBASE_MESSAGING_SENDER_ID}',
  FIREBASE_APP_ID: '${FIREBASE_APP_ID}',
  FIREBASE_MEASUREMENT_ID: '${FIREBASE_MEASUREMENT_ID}',
  API_BASE_URL: '${API_BASE_URL}',
  RAZORPAY_KEY_ID: '${RAZORPAY_KEY_ID}'
};
ENVEOF

echo "Done!"
