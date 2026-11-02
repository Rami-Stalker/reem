# Testing signing key

`testing-keystore.b64` is a **testing-only** signing key (alias `reem-testing`,
password `reem-testing`). CI signs tester APKs with it whenever the real release
keystore secrets are not configured, so every tester build carries the same
signature and installs as an **update** over the previous one.

It is not a release key and must never be used for the Play Store — set the
`ANDROID_KEYSTORE_*` secrets for that (see `.github/workflows/android-apk.yml`).
