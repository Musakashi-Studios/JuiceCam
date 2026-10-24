#!/usr/bin/env python3
"""Upload guide images to Cloudinary without exposing credentials in the CLI."""

from __future__ import annotations

import argparse
import base64
import http.client
import json
import mimetypes
import os
import re
import sys
import uuid
from pathlib import Path
from typing import Any, Mapping, Optional, Sequence
from urllib.parse import unquote, urlsplit


PACKAGE_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CREDENTIALS_FILE = PACKAGE_ROOT / ".env"
CREDENTIAL_KEYS = (
    "CLOUDINARY_CLOUD_NAME",
    "CLOUDINARY_API_KEY",
    "CLOUDINARY_API_SECRET",
)
IMAGE_MIME_OVERRIDES = {".svg": "image/svg+xml"}
UPLOAD_CHUNK_SIZE = 1024 * 1024
RESPONSE_LIMIT_BYTES = 1024 * 1024


class UploadError(RuntimeError):
    """A safe-to-display upload or configuration failure."""


def _unquote_value(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in ("'", '"'):
        return value[1:-1]
    return value


def _read_credentials_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.is_file():
        return values

    assignment = re.compile(r"^\s*(CLOUDINARY_[A-Z_]+)\s*=\s*(.*?)\s*$")
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as error:
        raise UploadError(f"Could not read credentials file: {path}") from error

    for line in lines:
        match = assignment.match(line)
        if match:
            key, value = match.groups()
            values[key] = _unquote_value(value)
    return values


def load_credentials(path: Path) -> dict[str, str]:
    """Load local credentials, with process environment values taking priority."""
    values = _read_credentials_file(path)

    cloudinary_url = os.environ.get("CLOUDINARY_URL", "").strip()
    if cloudinary_url:
        parsed = urlsplit(cloudinary_url)
        if (
            parsed.scheme != "cloudinary"
            or not parsed.username
            or not parsed.password
            or not parsed.hostname
        ):
            raise UploadError("CLOUDINARY_URL is not a valid Cloudinary credential URL.")
        values.update(
            {
                "CLOUDINARY_API_KEY": unquote(parsed.username),
                "CLOUDINARY_API_SECRET": unquote(parsed.password),
                "CLOUDINARY_CLOUD_NAME": parsed.hostname,
            }
        )

    for key in CREDENTIAL_KEYS:
        environment_value = os.environ.get(key)
        if environment_value:
            values[key] = environment_value.strip()

    missing = [key for key in CREDENTIAL_KEYS if not values.get(key)]
    if missing:
        names = ", ".join(missing)
        raise UploadError(
            f"Missing Cloudinary credentials: {names}. Set environment variables "
            f"or fill in {path}."
        )

    cloud_name = values["CLOUDINARY_CLOUD_NAME"]
    if not re.fullmatch(r"[A-Za-z0-9_-]+", cloud_name):
        raise UploadError("CLOUDINARY_CLOUD_NAME contains unsupported characters.")
    return values


def _resolve_image(path_text: str) -> tuple[Path, str]:
    path = Path(path_text).expanduser()
    try:
        resolved_path = path.resolve(strict=True)
    except OSError as error:
        raise UploadError(f"Image file does not exist or cannot be read: {path_text}") from error

    if not resolved_path.is_file():
        raise UploadError(f"Image path is not a file: {path_text}")

    mime_type = IMAGE_MIME_OVERRIDES.get(resolved_path.suffix.lower())
    if mime_type is None:
        mime_type = mimetypes.guess_type(resolved_path.name)[0]
    if not mime_type or not mime_type.startswith("image/"):
        raise UploadError(f"Unsupported image file type: {resolved_path.name}")
    return resolved_path, mime_type


def _image_public_id(path: Path) -> str:
    public_id = re.sub(r"[^A-Za-z0-9_-]+", "-", path.stem).strip("-_")
    if not public_id:
        raise UploadError(f"Could not make a Cloudinary public ID from: {path.name}")
    return public_id


def _form_field(boundary: str, name: str, value: str) -> bytes:
    if "\r" in value or "\n" in value:
        raise UploadError(f"Upload parameter {name} contains a line break.")
    return (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="{name}"\r\n\r\n'
        f"{value}\r\n"
    ).encode("utf-8")


def _decode_response(status: int, response_bytes: bytes) -> Mapping[str, Any]:
    try:
        payload = json.loads(response_bytes.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise UploadError(f"Cloudinary returned an unreadable response (HTTP {status}).") from error

    if not isinstance(payload, dict):
        raise UploadError(f"Cloudinary returned an unexpected response (HTTP {status}).")
    if status < 200 or status >= 300:
        error_payload = payload.get("error")
        message = error_payload.get("message") if isinstance(error_payload, dict) else None
        if isinstance(message, str) and message:
            raise UploadError(f"Cloudinary upload failed (HTTP {status}): {message}")
        raise UploadError(f"Cloudinary upload failed (HTTP {status}).")
    return payload


def upload_image(
    path: Path,
    mime_type: str,
    credentials: Mapping[str, str],
    folder: str,
    public_id: str,
    overwrite: bool,
    timeout_seconds: float,
) -> str:
    """Stream one image to Cloudinary and return its secure delivery URL."""
    cloud_name = credentials["CLOUDINARY_CLOUD_NAME"]
    api_key = credentials["CLOUDINARY_API_KEY"]
    api_secret = credentials["CLOUDINARY_API_SECRET"]
    boundary = f"----JuiceCamUpload{uuid.uuid4().hex}"

    fields = [
        ("folder", folder),
        ("public_id", public_id),
        ("overwrite", "true" if overwrite else "false"),
    ]
    field_parts = [_form_field(boundary, name, value) for name, value in fields if value]

    filename = path.name.replace('"', "_").replace("\r", "_").replace("\n", "_")
    filename = filename.encode("ascii", "replace").decode("ascii")
    file_header = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="file"; filename="{filename}"\r\n'
        f"Content-Type: {mime_type}\r\n\r\n"
    ).encode("ascii")
    file_suffix = b"\r\n"
    closing = f"--{boundary}--\r\n".encode("ascii")
    content_length = (
        sum(len(part) for part in field_parts)
        + len(file_header)
        + path.stat().st_size
        + len(file_suffix)
        + len(closing)
    )

    endpoint = f"/v1_1/{cloud_name}/image/upload"
    basic_token = base64.b64encode(f"{api_key}:{api_secret}".encode("utf-8")).decode("ascii")
    connection = http.client.HTTPSConnection("api.cloudinary.com", timeout=timeout_seconds)
    try:
        connection.putrequest("POST", endpoint)
        connection.putheader("Authorization", f"Basic {basic_token}")
        connection.putheader("Content-Type", f"multipart/form-data; boundary={boundary}")
        connection.putheader("Content-Length", str(content_length))
        connection.endheaders()

        for part in field_parts:
            connection.send(part)
        connection.send(file_header)
        with path.open("rb") as image_file:
            while True:
                chunk = image_file.read(UPLOAD_CHUNK_SIZE)
                if not chunk:
                    break
                connection.send(chunk)
        connection.send(file_suffix)
        connection.send(closing)

        response = connection.getresponse()
        response_bytes = response.read(RESPONSE_LIMIT_BYTES + 1)
        if len(response_bytes) > RESPONSE_LIMIT_BYTES:
            raise UploadError("Cloudinary response exceeded the expected size limit.")
        payload = _decode_response(response.status, response_bytes)
    except (OSError, http.client.HTTPException, TimeoutError) as error:
        raise UploadError(f"Could not reach Cloudinary: {error}") from error
    finally:
        connection.close()

    secure_url = payload.get("secure_url")
    if not isinstance(secure_url, str) or not secure_url.startswith("https://"):
        raise UploadError("Cloudinary reported success without a secure image URL.")
    return secure_url


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Upload one or more guide images to Cloudinary and print their secure URLs."
    )
    parser.add_argument("images", nargs="+", help="Image paths to upload")
    parser.add_argument(
        "--folder",
        default="juicecam/guide",
        help="Cloudinary folder (default: juicecam/guide)",
    )
    parser.add_argument(
        "--public-id",
        help="Set the public ID for one image; otherwise each filename is used",
    )
    parser.add_argument(
        "--credentials-file",
        type=Path,
        default=DEFAULT_CREDENTIALS_FILE,
        help=f"Local dotenv file (default: {DEFAULT_CREDENTIALS_FILE})",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Replace an existing asset with the same folder and public ID",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=60.0,
        help="Request timeout in seconds (default: 60)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show planned Cloudinary IDs without contacting Cloudinary",
    )
    return parser


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.timeout <= 0:
        parser.error("--timeout must be greater than zero")
    if args.public_id and len(args.images) != 1:
        parser.error("--public-id can only be used with one image")

    try:
        resolved_images = [_resolve_image(image) for image in args.images]
        public_ids = [args.public_id or _image_public_id(path) for path, _ in resolved_images]
        if len(set(public_ids)) != len(public_ids):
            raise UploadError("The input files resolve to duplicate public IDs; rename a file or set --public-id.")

        if args.dry_run:
            for (path, _), public_id in zip(resolved_images, public_ids):
                print(f"{path.name} -> {args.folder}/{public_id}")
            return 0

        credentials = load_credentials(args.credentials_file)
        for (path, mime_type), public_id in zip(resolved_images, public_ids):
            secure_url = upload_image(
                path=path,
                mime_type=mime_type,
                credentials=credentials,
                folder=args.folder,
                public_id=public_id,
                overwrite=args.overwrite,
                timeout_seconds=args.timeout,
            )
            print(f"{path.name}\t{secure_url}")
    except UploadError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
