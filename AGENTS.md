# EurekaLife repository guidance

This repository contains the WiseLife iPhone / Apple Watch app, native Ring SDK dependencies, and Mac Companion. The historical `wrist-notes` directory and bundle identifiers are intentional; changing them affects app data, pairing, and signing.

- iPhone / Watch: `apps/wrist-notes`; Mac: `apps/wiselife-mac`.
- Start with `docs/INDEX.md` and the affected app's README. Follow [documentation maintenance rules](docs/documentation-rules.md).
- Preserve user recordings, SQLite databases, Keychain credentials, local model files, and dirty worktrees. Do not uninstall apps or reset device/simulator data as a routine validation step.
- Keep signing material, credentials, runtime databases, recordings, model weights, generated builds, and device captures out of Git.
- Keep `pod install`, SDK integrity checks, and Xcode source membership synchronized with iPhone changes. Do not replace the whole project file merely to add a source.
- Validate native code with relevant tests and Xcode builds. Report compilation, simulator tests, real-device acceptance, signing, and releases separately.
- Mac tests must not silently download model weights or publish a LAN service. Use synthetic data and test-local stores.
- Preserve third-party license and privacy notices. Update the existing docs/index for changes; publish or release only within user authorization.
