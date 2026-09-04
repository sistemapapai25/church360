"""Publica o .aab gerado no CI para uma faixa do Google Play, usando
credenciais ADC (Workload Identity Federation) — sem chave JSON.
"""
import os
import sys

import google.auth
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

PACKAGE_NAME = os.environ["ANDROID_PACKAGE_NAME"]
TRACK = os.environ["PLAY_TRACK"]
AAB_PATH = "build/app/outputs/bundle/release/app-release.aab"


def run_smoke_test(edits) -> None:
    """Confirma OIDC + permissão no Play Console sem publicar nada:
    cria um rascunho de edição e descarta em seguida."""
    edit_id = edits.insert(body={}, packageName=PACKAGE_NAME).execute()["id"]
    edits.delete(editId=edit_id, packageName=PACKAGE_NAME).execute()
    print(f"Smoke test OK: acesso confirmado a {PACKAGE_NAME} via Play Developer API")


def main() -> None:
    credentials, _ = google.auth.default(
        scopes=["https://www.googleapis.com/auth/androidpublisher"]
    )
    service = build("androidpublisher", "v3", credentials=credentials)
    edits = service.edits()

    if TRACK == "smoke_test":
        run_smoke_test(edits)
        return

    if not os.path.isfile(AAB_PATH):
        sys.exit(f"Arquivo não encontrado: {AAB_PATH}")

    edit_id = edits.insert(body={}, packageName=PACKAGE_NAME).execute()["id"]

    media = MediaFileUpload(AAB_PATH, mimetype="application/octet-stream")
    bundle = edits.bundles().upload(
        editId=edit_id,
        packageName=PACKAGE_NAME,
        media_body=media,
    ).execute()
    version_code = bundle["versionCode"]

    edits.tracks().update(
        editId=edit_id,
        track=TRACK,
        packageName=PACKAGE_NAME,
        body={
            "releases": [
                {"versionCodes": [str(version_code)], "status": "completed"}
            ]
        },
    ).execute()

    edits.commit(editId=edit_id, packageName=PACKAGE_NAME).execute()
    print(f"Publicado versionCode {version_code} na faixa '{TRACK}' de {PACKAGE_NAME}")


if __name__ == "__main__":
    main()
