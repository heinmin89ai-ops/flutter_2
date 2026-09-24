#!/usr/bin/env python3
"""Vendor-side licence key generator for Pharmacy POS.

Produces the JWT that a shop types into the app's Activation Key screen.

    python3 tools/license_generator.py \
        --client "Hein Pharmacy, Yangon" \
        --exp 2027-01-01 \
        --features '{"retail": true, "wholesale": true, "cloud_backup": false}'

No third-party dependencies: only the standard library, so it runs on a clean
machine without `pip install`. The signing scheme is HS256 (HMAC-SHA256 over
`base64url(header) + "." + base64url(payload)`), which the Flutter app verifies
with the same secret in `lib/features/license/application/jwt_decoder.dart`.

SAFETY WARNING — read docs/PHASE2_LICENSE.md before issuing a customer key.
HS256 uses one shared secret. That secret is compiled into the shipped APK, so
anyone who extracts it can forge keys. This protects against casual editing of
the licence row, not against a determined attacker. See "Upgrade path" in the
doc for the Ed25519 design that removes the weakness.
"""

from __future__ import annotations

import argparse
import base64
import calendar
import hashlib
import hmac
import json
import os
import sys
from datetime import datetime, timedelta, timezone

# The app ships the same constant. Override with --secret or the environment
# variable below on both sides when you rotate it.
DEFAULT_SECRET = "pharmacy-pos-dev-secret-CHANGE-ME-0f3a9c7d51b642e8"
SECRET_ENV = "PHARMACY_LICENSE_SECRET"

ALG = "HS256"
ISSUER = "pharmacy-pos"


def _b64encode(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def _b64decode(segment: str) -> bytes:
    padding = "=" * (-len(segment) % 4)
    return base64.urlsafe_b64decode(segment + padding)


def _sign(signing_input: str, secret: str) -> str:
    digest = hmac.new(
        secret.encode("utf-8"), signing_input.encode("ascii"), hashlib.sha256
    ).digest()
    return _b64encode(digest)


def build_key(claims: dict, secret: str) -> str:
    header = {"alg": ALG, "typ": "JWT"}
    h = _b64encode(json.dumps(header, separators=(",", ":"), sort_keys=True).encode())
    p = _b64encode(
        json.dumps(claims, separators=(",", ":"), sort_keys=True).encode("utf-8")
    )
    signing_input = f"{h}.{p}"
    return f"{signing_input}.{_sign(signing_input, secret)}"


def verify_key(key: str, secret: str, *, now: datetime | None = None) -> dict:
    """Re-implement the app's checks so the tool can self-test and --verify."""
    parts = key.strip().split(".")
    if len(parts) != 3:
        raise ValueError("key must have exactly three dot-separated segments")
    header_b64, payload_b64, signature_b64 = parts

    header = json.loads(_b64decode(header_b64))
    if header.get("alg") != ALG:
        # "alg": "none" and an RS256/HS256 confusion both land here.
        raise ValueError(f"unsupported alg {header.get('alg')!r}")

    expected = _sign(f"{header_b64}.{payload_b64}", secret)
    if not hmac.compare_digest(expected, signature_b64):
        raise ValueError("signature mismatch")

    claims = json.loads(_b64decode(payload_b64))
    now = now or datetime.now(timezone.utc)
    if "exp" in claims:
        if claims["exp"] is None:
            raise ValueError("exp is null")
        if now.timestamp() >= float(claims["exp"]):
            raise ValueError("key expired")
    return claims


def _parse_exp(raw: str) -> tuple[int, str]:
    """Accept an ISO date, a `+Nd`/`+Ny` offset, or a unix timestamp."""
    now = datetime.now(timezone.utc)
    if raw.startswith("+") and len(raw) > 2 and raw[-1] in "dmy":
        amount = int(raw[1:-1])
        if raw[-1] == "d":
            end = now + timedelta(days=amount)
        else:
            months = amount * (12 if raw[-1] == "y" else 1)
            year, month = now.year + (now.month - 1 + months) // 12, (
                now.month - 1 + months
            ) % 12 + 1
            # Feb 30 guard: clamp to the last day of the target month.
            day = min(now.day, calendar.monthrange(year, month)[1])
            end = now.replace(year=year, month=month, day=day)
        end = end.replace(hour=23, minute=59, second=59)
        return int(end.timestamp()), end.date().isoformat()
    if raw.lstrip("-").isdigit():
        stamp = int(raw)
        return stamp, datetime.fromtimestamp(stamp, timezone.utc).date().isoformat()
    parsed = datetime.fromisoformat(raw)
    if parsed.tzinfo is None:
        # A bare date means "usable through that day", not midnight of it.
        parsed = parsed.replace(hour=23, minute=59, second=59)
        parsed = parsed.replace(tzinfo=timezone.utc)
    return int(parsed.timestamp()), parsed.date().isoformat()


def _self_test(secret: str) -> int:
    """Exercise the accept/reject paths. Exit non-zero on any surprise."""
    failures: list[str] = []
    checked = 0
    claims = {
        "iss": ISSUER,
        "sub": "self-test",
        "iat": 1_700_000_000,
        "exp": 4_102_444_800,  # 2100-01-01
        "features": {"retail": True, "wholesale": False},
    }
    key = build_key(claims, secret)

    def check(label: str, mutation: str, expect_ok: bool) -> None:
        nonlocal checked
        checked += 1
        try:
            verify_key(mutation, secret)
            got = True
        except ValueError:
            got = False
        if got != expect_ok:
            failures.append(f"{label}: accepted={got} expected={expect_ok}")

    check("round trip", key, True)
    head, payload, sig = key.split(".")
    forged = json.dumps(
        {**claims, "features": {"retail": True, "wholesale": True}},
        separators=(",", ":"),
        sort_keys=True,
    )
    check(
        "feature escalation",
        f"{head}.{_b64encode(forged.encode())}.{sig}",
        False,
    )
    flipped = f"{head}.{payload}.{sig[:-2]}{'A' if sig[-1] != 'A' else 'B'}"
    check("flipped signature byte", flipped, False)
    none_header = _b64encode(
        json.dumps({"alg": "none", "typ": "JWT"}, separators=(",", ":"), sort_keys=True).encode()
    )
    check("alg none", f"{none_header}.{payload}.{sig}", False)
    check("trailing segment dropped", f"{head}.{payload}", False)
    check("expired key", build_key({**claims, "exp": 1_500_000_000}, secret), False)
    check("key signed with another secret", build_key(claims, "another-secret"), False)

    if failures:
        for line in failures:
            print(f"FAIL {line}", file=sys.stderr)
        return 1
    print(f"self-test OK ({checked} cases)")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Generate a Pharmacy POS activation key (HS256 JWT).",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("--client", help="Client / pharmacy name, e.g. 'Hein Pharmacy'")
    parser.add_argument(
        "--exp",
        help="Expiry: ISO date (2027-01-01), +365d, +2y, +18m, or a unix timestamp",
    )
    parser.add_argument(
        "--features",
        help='JSON object of module flags, e.g. \'{"retail": true}\'',
    )
    parser.add_argument("--sub", help="Stable customer id (defaults to --client)")
    parser.add_argument(
        "--no-expiry",
        action="store_true",
        help="Issue a perpetual licence (exp omitted)",
    )
    parser.add_argument("--secret", default=os.environ.get(SECRET_ENV, DEFAULT_SECRET))
    parser.add_argument("--verify", metavar="KEY", help="Check an existing key and exit")
    parser.add_argument(
        "--self-test", action="store_true", help="Run built-in accept/reject cases"
    )
    parser.add_argument(
        "--pretty", action="store_true", help="Print the decoded claims as well"
    )
    args = parser.parse_args(argv)

    if args.self_test:
        return _self_test(args.secret)

    if args.verify:
        try:
            claims = verify_key(args.verify, args.secret)
        except ValueError as exc:
            print(f"REJECTED: {exc}", file=sys.stderr)
            return 1
        print(json.dumps(claims, indent=2, sort_keys=True))
        return 0

    missing = [
        name
        for name, value in (("--client", args.client), ("--exp", args.exp), ("--features", args.features))
        if value is None and not (name == "--exp" and args.no_expiry)
    ]
    if missing:
        parser.error("missing required argument(s): " + ", ".join(missing))

    try:
        features = json.loads(args.features)
    except json.JSONDecodeError as exc:
        print(f"--features is not valid JSON: {exc}", file=sys.stderr)
        return 2
    if not isinstance(features, dict) or not features:
        print("--features must be a non-empty JSON object", file=sys.stderr)
        return 2
    non_bool = [k for k, v in features.items() if not isinstance(v, bool)]
    if non_bool:
        print(
            f"--features values must be true/false; got: {', '.join(non_bool)}",
            file=sys.stderr,
        )
        return 2

    claims: dict = {
        "iss": ISSUER,
        "sub": args.sub or args.client,
        "client": args.client,
        "iat": int(datetime.now(timezone.utc).timestamp()),
        "features": features,
    }
    shown = "never"
    if not args.no_expiry:
        claims["exp"], shown = _parse_exp(args.exp)

    key = build_key(claims, args.secret)

    # Never hand back a key the app would refuse.
    verify_key(key, args.secret)

    print(key)
    if args.pretty:
        print(
            f"\n# client  : {args.client}\n# expires : {shown}"
            f"\n# modules : {', '.join(f'{k}={v}' for k, v in sorted(features.items()))}",
            file=sys.stderr,
        )
    if args.secret == DEFAULT_SECRET:
        print(
            "\nWARNING: used the built-in development secret. Set "
            f"{SECRET_ENV} (or --secret) to the value compiled into the app "
            "before issuing a customer key.",
            file=sys.stderr,
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
