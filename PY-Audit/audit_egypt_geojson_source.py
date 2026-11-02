
#!/usr/bin/env python3
"""Reproducible provenance audit for AgroShift's Egypt governorates GeoJSON.

Run from the repository root:
    python PY-Audit/audit_egypt_geojson_source.py

Uses Python standard-library modules only.
Internet access is required to retrieve the pinned upstream file and
cross-check current geoBoundaries metadata.
"""

from __future__ import annotations

import hashlib
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]

ASSET_PATH = ROOT / "assets" / "geo" / "egypt_governorates.geojson"
ATTRIBUTION_PATH = ROOT / "assets" / "geo" / "ATTRIBUTION.txt"

# Historical source revision used for reproducible geometry comparison.
UPSTREAM_COMMIT = "9469f09"

UPSTREAM_PATH = (
    "releaseData/gbOpen/EGY/ADM1/"
    "geoBoundaries-EGY-ADM1_simplified.geojson"
)

UPSTREAM_URL = (
    "https://media.githubusercontent.com/media/wmgeolab/geoBoundaries/"
    f"{UPSTREAM_COMMIT}/{UPSTREAM_PATH}"
)

# SHA-256 recorded in the Git LFS pointer for the pinned upstream asset.
EXPECTED_UPSTREAM_SHA256 = (
    "6f521038eaf80b2925677b05f1fcb65f5f976bfd61ebbe0aef369c85895336a2"
)

METADATA_URL = (
    "https://www.geoboundaries.org/api/current/gbOpen/EGY/ADM1/"
)

EXPECTED_BOUNDARY_ID = "EGY-ADM1-46179711"
EXPECTED_FEATURE_COUNT = 27
TIMEOUT_SECONDS = 45


class AuditFailure(RuntimeError):
    """Raised when an audit assertion fails."""


def require(condition: bool, message: str) -> None:
    """Fail the audit immediately if a required condition is not met."""
    if not condition:
        raise AuditFailure(message)


def fetch_bytes(url: str) -> bytes:
    """Download a resource and return its bytes."""
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": "AgroShift-Egypt-GeoJSON-Provenance-Audit/1.0"
        },
    )

    with urllib.request.urlopen(
        request,
        timeout=TIMEOUT_SECONDS,
    ) as response:
        require(
            200 <= response.status < 300,
            f"Unexpected HTTP status {response.status}: {url}",
        )
        return response.read()


def read_json(path: Path) -> dict[str, Any]:
    """Read a UTF-8 JSON object from a local file."""
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise AuditFailure(
            f"Cannot read valid JSON from {path}: {exc}"
        ) from exc

    require(
        isinstance(value, dict),
        f"Expected a JSON object in {path}",
    )

    return value


def normalized_properties(properties: Any) -> dict[str, Any]:
    """Remove the sole locally permitted property addition."""
    require(
        isinstance(properties, dict),
        "Feature properties must be JSON objects",
    )

    normalized = dict(properties)
    normalized.pop("nameAr", None)

    return normalized


def validate_feature_collection(
    value: dict[str, Any],
    label: str,
) -> list[dict[str, Any]]:
    """Validate basic GeoJSON structure and stable feature identifiers."""
    require(
        value.get("type") == "FeatureCollection",
        f"{label}: root type must be FeatureCollection",
    )

    features = value.get("features")

    require(
        isinstance(features, list),
        f"{label}: features must be a list",
    )

    require(
        len(features) == EXPECTED_FEATURE_COUNT,
        (
            f"{label}: expected {EXPECTED_FEATURE_COUNT} features, "
            f"found {len(features)}"
        ),
    )

    identifiers: list[str] = []

    for index, feature in enumerate(features):
        require(
            isinstance(feature, dict)
            and feature.get("type") == "Feature",
            f"{label}: feature {index} is invalid",
        )

        properties = feature.get("properties")

        require(
            isinstance(properties, dict),
            f"{label}: feature {index} has no valid properties object",
        )

        shape_iso = properties.get("shapeISO")

        require(
            isinstance(shape_iso, str) and bool(shape_iso.strip()),
            f"{label}: feature {index} has no valid shapeISO",
        )

        identifiers.append(shape_iso)

    require(
        len(set(identifiers)) == len(identifiers),
        f"{label}: duplicate shapeISO identifiers found",
    )

    return features


def main() -> int:
    """Execute the provenance audit."""
    print("AgroShift Egypt ADM1 GeoJSON provenance audit")
    print("=" * 48)

    require(
        ASSET_PATH.is_file(),
        f"Missing local asset: {ASSET_PATH}",
    )

    require(
        ATTRIBUTION_PATH.is_file(),
        f"Missing attribution file: {ATTRIBUTION_PATH}",
    )

    local = read_json(ASSET_PATH)

    local_features = validate_feature_collection(
        local,
        "Local asset",
    )

    attribution = ATTRIBUTION_PATH.read_text(encoding="utf-8")

    # 1. Retrieve the historical source revision.
    print("Downloading pinned upstream GeoJSON...")

    try:
        upstream_bytes = fetch_bytes(UPSTREAM_URL)
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        raise AuditFailure(
            "Could not retrieve the pinned upstream GeoJSON. "
            f"Cannot complete source comparison: {exc}"
        ) from exc

    # 2. Verify the immutable upstream content hash.
    actual_hash = hashlib.sha256(upstream_bytes).hexdigest()

    require(
        actual_hash == EXPECTED_UPSTREAM_SHA256,
        (
            "Pinned upstream SHA-256 mismatch. "
            f"Expected {EXPECTED_UPSTREAM_SHA256}; "
            f"received {actual_hash}"
        ),
    )

    print(f"PASS: upstream SHA-256 = {actual_hash}")

    # 3. Parse and validate the upstream GeoJSON.
    try:
        upstream = json.loads(upstream_bytes.decode("utf-8"))
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise AuditFailure(
            f"Pinned upstream is not valid UTF-8 JSON: {exc}"
        ) from exc

    require(
        isinstance(upstream, dict),
        "Pinned upstream root must be a JSON object",
    )

    upstream_features = validate_feature_collection(
        upstream,
        "Pinned upstream",
    )

    # 4. Compare features by stable shapeISO, not array order.
    upstream_by_id = {
        feature["properties"]["shapeISO"]: feature
        for feature in upstream_features
    }

    local_by_id = {
        feature["properties"]["shapeISO"]: feature
        for feature in local_features
    }

    require(
        set(local_by_id) == set(upstream_by_id),
        "Local and upstream governorate identifiers differ",
    )

    for shape_iso in sorted(upstream_by_id):
        source_feature = upstream_by_id[shape_iso]
        local_feature = local_by_id[shape_iso]

        require(
            local_feature.get("geometry")
            == source_feature.get("geometry"),
            f"{shape_iso}: geometry differs from pinned upstream",
        )

        require(
            normalized_properties(local_feature.get("properties"))
            == normalized_properties(
                source_feature.get("properties")
            ),
            (
                f"{shape_iso}: properties differ beyond the "
                "permitted nameAr addition"
            ),
        )

        arabic_name = local_feature["properties"].get("nameAr")

        require(
            isinstance(arabic_name, str) and bool(arabic_name.strip()),
            f"{shape_iso}: missing or empty Arabic nameAr",
        )

    print(
        "PASS: all 27 governorate geometries match the pinned source."
    )
    print(
        "PASS: all other properties match after excluding nameAr."
    )
    print(
        "PASS: every governorate has a non-empty Arabic name."
    )

    # 5. Check for required provenance references in the attribution file.
    required_terms = (
        "geoBoundaries",
        UPSTREAM_COMMIT,
        "OpenStreetMap",
        "ODbL",
        "CC BY 4.0",
        "nameAr",
    )

    missing_terms = [
        term
        for term in required_terms
        if term.casefold() not in attribution.casefold()
    ]

    require(
        not missing_terms,
        (
            "ATTRIBUTION.txt is missing expected provenance terms: "
            + ", ".join(missing_terms)
        ),
    )

    print("PASS: required provenance terms are present in ATTRIBUTION.txt.")

    # 6. Cross-check current dataset metadata.
    # This is a live metadata check, not a historical license snapshot.
    print("Checking current geoBoundaries metadata...")

    try:
        metadata_bytes = fetch_bytes(METADATA_URL)
        metadata = json.loads(metadata_bytes.decode("utf-8"))
    except (
        urllib.error.URLError,
        TimeoutError,
        OSError,
        UnicodeError,
        json.JSONDecodeError,
    ) as exc:
        raise AuditFailure(
            f"Could not verify current geoBoundaries metadata: {exc}"
        ) from exc

    require(
        isinstance(metadata, dict),
        "Current geoBoundaries metadata is not a JSON object",
    )

    boundary_id = metadata.get("boundaryID")

    require(
        boundary_id == EXPECTED_BOUNDARY_ID,
        (
            "Unexpected current boundaryID. "
            f"Expected {EXPECTED_BOUNDARY_ID!r}; "
            f"received {boundary_id!r}. "
            "Review the dataset identity before proceeding."
        ),
    )

    license_text = str(metadata.get("boundaryLicense", ""))
    license_source = str(metadata.get("licenseSource", ""))

    require(
        bool(license_text.strip()),
        "Current metadata has no boundaryLicense value",
    )

    require(
        bool(license_source.strip()),
        "Current metadata has no licenseSource value",
    )

    license_lower = license_text.casefold()

    require(
        any(
            term in license_lower
            for term in (
                "odbl",
                "open data commons",
                "open database license",
            )
        ),
        (
            "Current source license requires manual review. "
            f"boundaryLicense={license_text!r}"
        ),
    )

    print(f"PASS: current boundaryID = {boundary_id}")
    print(f"INFO: current boundaryLicense = {license_text}")
    print(f"INFO: current licenseSource = {license_source}")
    print(
        "NOTE: current metadata is a live cross-check, "
        "not a historical license snapshot."
    )

    print()
    print("AUDIT RESULT: PASS")

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AuditFailure as exc:
        print(f"AUDIT RESULT: FAIL — {exc}", file=sys.stderr)
        raise SystemExit(1)
