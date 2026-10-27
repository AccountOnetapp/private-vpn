# Third-party components

The app keeps Xray and AmneziaWG in separate extension processes. The following
versions are pinned for reproducible builds.

## XTLS libXray

- Project: <https://github.com/XTLS/libXray>
- Release: `v26.10.21` / Go mirror `v1.261021.0`
- Commit: `dbe95129fa96689c4643ddca52c278448eec6df1`
- License: MIT
- Apple archive SHA-256:
  `f318d216bb3b16b18d7b04c54789d1feaa6b7571433ed5582c1fe776e3776ef1`

The downloaded libXray archive contains Xray-core. Xray-core is distributed
under Mozilla Public License 2.0; its source is available at
<https://github.com/XTLS/Xray-core>.

## AmneziaWG Apple

- Project: <https://github.com/amnezia-vpn/amneziawg-apple>
- Commit: `9d5ee60edefa95b933a738dd7cda671dd18021fc`
- Description: official WireGuardKit and AmneziaWG Go bridge for Apple systems
- License: MIT, reproduced in the upstream repository README and source headers

The pinned upstream source and its notices remain available in the Git
submodule at `ios/Packages/amneziawg-apple`.

## Distribution note

Before an App Store release, expose applicable open-source acknowledgements in
the application settings and complete a release-specific license review. This
file records the versions used by the current development build; it is not a
substitute for that review.
