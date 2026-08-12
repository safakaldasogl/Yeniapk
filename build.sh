#!/bin/bash
# Manual APK build for Archi (WebView wrapper around app/assets/index.html)
# Uses Ubuntu-packaged Android tooling (aapt, dalvik-exchange, zipalign, apksigner)
# since Google's SDK repository (dl.google.com) is not reachable from this environment.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$ROOT/app"
BUILD="$ROOT/build"
DIST="$ROOT/dist"
PKG_DIR="$BUILD/gen/com/archi/app"

ANDROID_JAR="/usr/lib/android-sdk/platforms/android-23/android.jar"
FRAMEWORK_RES="/usr/share/android-framework-res/framework-res.apk"
DX="/usr/lib/android-sdk/build-tools/debian/dx"
KEYSTORE="$ROOT/archi-release.keystore"

rm -rf "$BUILD" "$DIST"
mkdir -p "$BUILD/obj" "$BUILD/apk" "$DIST"

echo "== Compiling Java sources =="
mkdir -p "$BUILD/obj"
find "$APP/src" -name "*.java" > "$BUILD/sources.txt"
javac -source 8 -target 8 -nowarn -Xlint:none \
  -bootclasspath "$ANDROID_JAR" \
  -classpath "$ANDROID_JAR" \
  -d "$BUILD/obj" \
  @"$BUILD/sources.txt"

echo "== Building classes.dex =="
"$DX" --dex --output="$BUILD/apk/classes.dex" "$BUILD/obj"

echo "== Packaging resources with aapt =="
aapt package -f \
  -M "$APP/AndroidManifest.xml" \
  -S "$APP/res" \
  -A "$APP/assets" \
  -I "$FRAMEWORK_RES" \
  -F "$BUILD/apk/archi-unsigned.apk"

echo "== Adding classes.dex to APK =="
( cd "$BUILD/apk" && aapt add archi-unsigned.apk classes.dex )

echo "== Zipaligning =="
zipalign -f -p 4 "$BUILD/apk/archi-unsigned.apk" "$BUILD/apk/archi-aligned.apk"

if [ ! -f "$KEYSTORE" ]; then
  echo "== Generating signing keystore (self-signed, personal use) =="
  keytool -genkeypair -v \
    -keystore "$KEYSTORE" \
    -alias archi \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass archi123 -keypass archi123 \
    -dname "CN=Archi, OU=Personal, O=Archi, L=, S=, C=TR"
fi

echo "== Signing APK =="
apksigner sign \
  --ks "$KEYSTORE" \
  --ks-pass pass:archi123 \
  --key-pass pass:archi123 \
  --out "$DIST/Archi.apk" \
  "$BUILD/apk/archi-aligned.apk"

echo "== Verifying signature =="
apksigner verify --verbose "$DIST/Archi.apk"

echo
echo "Build complete: $DIST/Archi.apk"
ls -la "$DIST/Archi.apk"
