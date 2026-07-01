# hev-socks5 SDK (AAR)

This module packages the Java API and prebuilt native libraries (.so) into an AAR.

Quick steps to produce AAR:

1. Build native `.so` for supported ABIs and copy them into the module:

```bash
./scripts/build_native_and_copy.sh
```

2. Build the AAR:

```bash
./gradlew :hev-socks5-sdk:assembleRelease
# AAR will be at hev-socks5-sdk/build/outputs/aar/
```

3. Publish to local Maven (optional):

Add a `maven-publish` block to `build.gradle` if you want to publish.

Notes:
- The native library is expected to be named `libhev-socks5-tunnel.so`.
- The Java API class is `hev.htproxy.TProxyService` and will load the native library automatically.
- Keep `ParcelFileDescriptor` alive in the caller until native stops using the fd.
