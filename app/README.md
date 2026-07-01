# Demo app

This demo app shows how to use the `hev-socks5-sdk` module.

Build & run (open in Android Studio or use Gradle):

```bash
# Build native libs and copy into sdk module
./scripts/build_native_and_copy.sh

# Build and install the demo app (requires connected device/emulator)
./gradlew :app:installDebug

# Launch app
adb shell am start -n com.example.hevsocks5demo/.MainActivity
```
