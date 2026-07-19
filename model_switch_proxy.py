#!/usr/bin/env python3
"""Reverse proxy in front of oobabooga's OpenAI-compatible API.

Text-generation-webui's OpenAI extension ignores the "model" field in
/v1/chat/completions and /v1/completions requests: it always answers with
whatever model is currently loaded. Tools like Roo Code only set that
field and never call /v1/internal/model/load, so picking a different
model in their UI has no effect.

This proxy sits in front of the real API: for those two endpoints it
reads the requested "model" name, compares it to the model reported by
/v1/internal/model/info, and calls /v1/internal/model/load first if they
differ. Everything else is passed straight through unchanged.

Point external tools at this proxy's port instead of the API port.
"""
import os

import requests
from flask import Flask, Response, request, stream_with_context

API_HOST = os.environ.get("OOBABOOGA_API_HOST", "127.0.0.1")
API_PORT = os.environ.get("OOBABOOGA_API_PORT", "5000")
PROXY_PORT = int(os.environ.get("MODEL_SWITCH_PROXY_PORT", "5005"))
API_BASE = f"http://{API_HOST}:{API_PORT}"

MODEL_SWITCH_PATHS = {"v1/chat/completions", "v1/completions"}
HOP_BY_HOP_HEADERS = {"content-encoding", "transfer-encoding", "connection", "host"}

app = Flask(__name__)


def get_loaded_model():
    resp = requests.get(f"{API_BASE}/v1/internal/model/info", timeout=10)
    resp.raise_for_status()
    return resp.json().get("model_name")


def load_model(model_name):
    resp = requests.post(
        f"{API_BASE}/v1/internal/model/load",
        json={"model_name": model_name},
        timeout=600,
    )
    resp.raise_for_status()


def maybe_switch_model(path, json_body):
    if path not in MODEL_SWITCH_PATHS or not json_body:
        return
    requested_model = json_body.get("model")
    if not requested_model:
        return
    try:
        current_model = get_loaded_model()
    except requests.RequestException as exc:
        print(f"[model-switch-proxy] could not read loaded model: {exc}")
        return
    if current_model and requested_model != current_model:
        print(f"[model-switch-proxy] switching model: {current_model} -> {requested_model}")
        try:
            load_model(requested_model)
        except requests.RequestException as exc:
            print(f"[model-switch-proxy] failed to load '{requested_model}': {exc}")


@app.route("/<path:path>", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
def proxy(path):
    body = request.get_data()
    json_body = request.get_json(silent=True) if request.method == "POST" else None

    maybe_switch_model(path, json_body)

    headers = {k: v for k, v in request.headers if k.lower() not in HOP_BY_HOP_HEADERS}
    upstream = requests.request(
        request.method,
        f"{API_BASE}/{path}",
        headers=headers,
        params=request.args,
        data=body,
        stream=True,
        timeout=600,
    )

    def generate():
        for chunk in upstream.iter_content(chunk_size=4096):
            if chunk:
                yield chunk

    response_headers = [
        (k, v) for k, v in upstream.headers.items() if k.lower() not in HOP_BY_HOP_HEADERS
    ]
    return Response(stream_with_context(generate()), status=upstream.status_code, headers=response_headers)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=PROXY_PORT, threaded=True)
