#!/bin/bash
# Build BootDebian.apk with the Android SDK (build-tools 34, platform android-34) and a JDK >= 11 (Android Studio's jbr works).
set -euo pipefail
cd "$(dirname "$0")"
S=${ANDROID_SDK:-$HOME/Library/Android/sdk}; BT=$S/build-tools/34.0.0; JAR=$S/platforms/android-34/android.jar
rm -rf build; mkdir -p build/gen build/cls
$BT/aapt2 link -o build/base.apk -I $JAR --manifest AndroidManifest.xml --java build/gen
javac --release 8 -cp $JAR -d build/cls src/dev/ibiza/boot/Main.java
$BT/d8 --release --lib $JAR --output build $(find build/cls -name '*.class')
cp build/base.apk build/app.apk; (cd build && zip -qj app.apk classes.dex)
$BT/zipalign -f 4 build/app.apk build/aligned.apk
$BT/apksigner sign --ks ${KEYSTORE:-$HOME/.android/debug.keystore} --ks-pass pass:android --out BootDebian.apk build/aligned.apk
