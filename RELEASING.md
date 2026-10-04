# Releasing

Pushing a `v*` tag runs `.github/workflows/release.yml`. It builds a universal (Apple Silicon + Intel)
app, signs it with Developer ID, notarizes and staples it, publishes the zip as a GitHub release, and
updates the Homebrew cask. The version comes from the tag.

```sh
git tag v0.3.0 && git push origin v0.3.0
```

## Secrets

The workflow needs these repository secrets (Settings → Secrets and variables → Actions):

| Secret | Value |
|---|---|
| `DEVELOPER_ID_P12` | Your Developer ID Application certificate and private key, exported from Keychain Access (My Certificates) as .p12, base64-encoded |
| `DEVELOPER_ID_P12_PASSWORD` | The password you set when exporting the .p12 |
| `NOTARY_KEY_P8` | Contents of an App Store Connect API key (.p8), from [Users and Access → Integrations](https://appstoreconnect.apple.com/access/integrations/api), role Developer |
| `NOTARY_KEY_ID` | That key's Key ID |
| `NOTARY_ISSUER` | The Issuer ID shown above the keys list |
| `HOMEBREW_TAP_TOKEN` | Optional. A fine-grained token with **Contents: read and write** on [marcneuwirth/homebrew-tap](https://github.com/marcneuwirth/homebrew-tap), so the release also updates the cask (`scripts/cask.sh`) |

Keep the .p12 password in a file rather than only on the clipboard, and make sure it has no trailing
newline. Keychain Access keeps a pasted newline as part of the password, but `gh secret set` strips it,
so the two no longer match and the import fails with "MAC verification failed".

```sh
openssl rand -hex 16 | tr -d '\n' > p12-password.txt && pbcopy < p12-password.txt
# Export the certificate from Keychain Access as DeveloperID.p12, pasting the password, then check it:
kc="$TMPDIR/p12test.keychain-db"; security create-keychain -p test "$kc" &&
    security import DeveloperID.p12 -k "$kc" -P "$(cat p12-password.txt)"; security delete-keychain "$kc"
gh secret set DEVELOPER_ID_P12_PASSWORD < p12-password.txt
base64 -i DeveloperID.p12 | gh secret set DEVELOPER_ID_P12
rm p12-password.txt DeveloperID.p12
```

## Building a release locally

Save notarization credentials once, then run `make release`:

```sh
xcrun notarytool store-credentials mullion --key AuthKey_<KEYID>.p8 --key-id <KEYID> --issuer <issuer-id>
NOTARY_PROFILE=mullion make release
```
