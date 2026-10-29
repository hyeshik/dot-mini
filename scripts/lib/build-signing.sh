#!/bin/bash
# Shared by the product and pilot builders. Credentials stay in the Keychain;
# only a notarytool profile name is passed to Apple's tools.

prepare_signing() {
    local configuration="$1" requested_identity="$2" notarize="$3"
    signing_identity="$requested_identity"
    signing_timestamp=--timestamp=none
    [ "$notarize" = true ] || return 0

    if [ "$configuration" != release ]; then
        echo "Notarization requires a Release build: use release --notarize." >&2
        return 1
    fi
    if [ -z "${NOTARY_KEYCHAIN_PROFILE:-}" ]; then
        echo "Set NOTARY_KEYCHAIN_PROFILE to a profile created with xcrun notarytool store-credentials." >&2
        return 1
    fi
    if [ -z "$requested_identity" ] || [ "$requested_identity" = - ]; then
        echo "Notarization requires a Developer ID Application signing identity (full name or SHA-1)." >&2
        return 1
    fi
    xcrun --find notarytool >/dev/null
    xcrun --find stapler >/dev/null

    local identities line fingerprint certificate matches=0
    local identity_pattern='[[:space:]]([[:xdigit:]]{40})[[:space:]]+"(Developer ID Application: [^"]+)"'
    local requested_hash
    requested_hash="$(printf '%s' "$requested_identity" | tr '[:lower:]' '[:upper:]')"
    identities="$(security find-identity -v -p codesigning)"
    while IFS= read -r line; do
        if [[ "$line" =~ $identity_pattern ]]; then
            fingerprint="${BASH_REMATCH[1]}"
            certificate="${BASH_REMATCH[2]}"
            if [ "$requested_identity" = "$certificate" ] || [ "$requested_hash" = "$fingerprint" ]; then
                signing_identity="$fingerprint"
                matches=$((matches + 1))
            fi
        fi
    done <<< "$identities"
    if [ "$matches" -ne 1 ]; then
        echo "Choose exactly one valid Developer ID Application identity from security find-identity -v -p codesigning; use its SHA-1 if names are duplicated." >&2
        return 1
    fi
    signing_timestamp=--timestamp
}

submit_notarization() {
    local submission_path="$1" notary_path="$2" response_path submission_id status
    local submission_exit=0
    response_path="$notary_path/submission.plist"
    echo "Submitting $(basename "$submission_path") to Apple's notary service…"
    xcrun notarytool submit "$submission_path" \
        --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" --wait \
        --output-format plist > "$response_path" || submission_exit=$?
    submission_id="$(/usr/bin/plutil -extract id raw -o - "$response_path" 2>/dev/null || true)"
    status="$(/usr/bin/plutil -extract status raw -o - "$response_path" 2>/dev/null || true)"
    if [ "$submission_exit" -ne 0 ] || [ "$status" != Accepted ] ||
       ! [[ "$submission_id" =~ ^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$ ]]; then
        echo "Notarization did not complete with Accepted status. Response: $response_path" >&2
        if [[ "$submission_id" =~ ^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$ ]]; then
            echo "Submission ID: $submission_id" >&2
            xcrun notarytool log "$submission_id" "$notary_path/log.json" \
                --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" || true
        fi
        return 1
    fi
}

notarize_app() {
    local app_path="$1" output_path app_name notary_path archive_path
    output_path="$(dirname "$app_path")"
    app_name="$(basename "$app_path" .app)"
    notary_path="$output_path/notarization"
    archive_path="$output_path/$app_name.zip"
    mkdir -m 700 "$notary_path"

    # Keep the upload separate from the final archive: only the latter contains
    # the stapled ticket and is emitted after every verification succeeds.
    ditto -c -k --sequesterRsrc --keepParent "$app_path" "$notary_path/submission.zip"
    submit_notarization "$notary_path/submission.zip" "$notary_path"

    xcrun stapler staple "$app_path"
    xcrun stapler validate "$app_path"
    codesign --verify --strict "$app_path"
    spctl --assess --type execute --verbose=2 "$app_path"
    # Publish the final filename only after packaging and hashing succeed.
    ditto -c -k --sequesterRsrc --keepParent "$app_path" "$notary_path/$app_name.zip"
    (cd "$notary_path" && shasum -a 256 "$app_name.zip" > "$app_name.zip.sha256")
    mv "$notary_path/$app_name.zip.sha256" "$output_path/$app_name.zip.sha256"
    mv "$notary_path/$app_name.zip" "$archive_path"
    echo "Notarized app: $app_path"
    echo "Distribution archive: $archive_path"
}

notarize_dmg() {
    local app_path="$1" output_path app_name notary_path dmg_path identifier
    output_path="$(dirname "$app_path")"
    app_name="$(basename "$app_path" .app)"
    notary_path="$output_path/notarization/dmg"
    dmg_path="$notary_path/$app_name.dmg"
    identifier="$(/usr/bin/plutil -extract CFBundleIdentifier raw -o - "$app_path/Contents/Info.plist")"

    # The copied app already carries its own ticket, including for offline use
    # after installation. The outer disk image receives a separate ticket.
    xcrun stapler validate "$app_path"
    mkdir -m 700 "$notary_path"
    mkdir "$notary_path/contents"
    ditto "$app_path" "$notary_path/contents/$app_name.app"
    ln -s /Applications "$notary_path/contents/Applications"
    hdiutil create -volname "$app_name" -srcfolder "$notary_path/contents" \
        -fs HFS+ -format UDZO "$dmg_path"
    hdiutil verify "$dmg_path"
    codesign --force --sign "$signing_identity" --timestamp \
        --identifier "$identifier.dmg" "$dmg_path"
    codesign --verify --strict "$dmg_path"
    submit_notarization "$dmg_path" "$notary_path"
    xcrun stapler staple "$dmg_path"
    xcrun stapler validate "$dmg_path"
    codesign --verify --strict "$dmg_path"
    spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg_path"

    (cd "$notary_path" && shasum -a 256 "$app_name.dmg" > "$app_name.dmg.sha256")
    mv "$notary_path/$app_name.dmg.sha256" "$output_path/$app_name.dmg.sha256"
    mv "$dmg_path" "$output_path/$app_name.dmg"
    echo "Notarized disk image: $output_path/$app_name.dmg"
}
