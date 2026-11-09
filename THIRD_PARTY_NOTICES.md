# Third-party licensing boundaries

Updated: 2026-11-09. This is an index of existing notices, not a replacement for their terms. The root Apache-2.0 license covers original EurekaLife code and project documentation only where no different license is specified. It does not relicense third-party materials or establish that all bundled dependencies are open source.

| Component | Existing terms / notice | Scope |
| --- | --- | --- |
| SQLite Vector | [Apache-2.0](apps/wrist-notes/Vendor/SQLiteVector/LICENSE.md), [provenance](apps/wrist-notes/Vendor/SQLiteVector/PROVENANCE.md) | Vendored SQLite Vector sources |
| FP16 | [MIT](apps/wrist-notes/Vendor/SQLiteVector/libs/fp16/LICENSE.upstream) | SQLite Vector's FP16 dependency |
| Ring BLE / recorder SDK | [Proprietary notice](pods/br_flutter_plugin_ble/Licenses/BRBluetoothLib.txt) and [package definition](pods/br_flutter_plugin_ble/br_flutter_plugin_ble.podspec) | Vendor SDKs remain separately licensed; this repository's license grants no right to relicense or redistribute them. The supplied notice alone does not establish public redistribution permission. Obtain any necessary authorization from the rights holder. |
| Opus | [COPYING](pods/br_flutter_plugin_ble/Licenses/Opus-COPYING.txt), [AUTHORS](pods/br_flutter_plugin_ble/Licenses/Opus-AUTHORS.txt) | Preserve the upstream notices bundled with the codec |
| WhisperKit / SpeakerKit and speaker models | [SDK and model notices](apps/wrist-notes/Sources/iPhone/SpeakerModels-NOTICES.txt) | MIT SDK and separately licensed CC-BY-4.0 model artifacts as described in the notice |
| Voice identity model | [Pinned model notice](apps/wrist-notes/Sources/iPhone/VoiceIdentityModels-NOTICES.txt) | Separately licensed model artifact; model weights are not covered by the root license |
| Lucide icons | [iPhone notice](apps/wrist-notes/Sources/iPhone/Lucide-LICENSE.txt), [website notice](apps/wiselife-website/lucide-LICENSE.txt) | Preserve each notice in redistributed copies |
| Inter font | [Font license](apps/wiselife-website/design-preview-v2/assets/inter-LICENSE.txt) | Website font assets |
| Mac dependencies and model catalog | [Third-party notices](apps/wiselife-mac/Resources/ThirdPartyNotices.txt), [resolved packages](apps/wiselife-mac/Package.resolved) | MLX, SwiftNIO and transitive dependencies retain upstream terms; downloaded model weights follow their own model licenses |

Dependency versions and additional upstream locations are recorded in the apps' `Package.resolved` files, `Podfile.lock`, and vendor manifests. Preserve applicable license texts and attribution when distributing source or binaries. Adding this root license does not resolve permissions absent from a vendor agreement.

## Building without the proprietary Ring SDK

Set `eurekaRing` to `false` in `apps/wrist-notes/Config/BuildFeatures.json`, then run `pod install --no-repo-update` in `apps/wrist-notes`. The existing build switch removes the Ring dependency and Ring-specific source membership; iPhone and Apple Watch features remain available. Existing device builds are not changed by this documentation.

Apple SDKs and frameworks are supplied by Apple under their own terms, not by this repository's Apache license. Model downloads and external AI services also retain their own access terms.
