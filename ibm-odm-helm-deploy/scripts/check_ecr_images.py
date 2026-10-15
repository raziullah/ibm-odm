#!/usr/bin/env python3
"""Verify every Helm-rendered workload image exists in the expected private ECR."""
import json, re, subprocess, sys
import yaml
manifest, account, region = sys.argv[1:4]
registry = f"{account}.dkr.ecr.{region}.amazonaws.com"
images = set()
for doc in yaml.safe_load_all(open(manifest, encoding="utf-8")):
    if not isinstance(doc, dict):
        continue
    spec = doc.get("spec") or {}
    kind = doc.get("kind")
    if kind == "CronJob":
        pod = (((spec.get("jobTemplate") or {}).get("spec") or {}).get("template") or {}).get("spec") or {}
    elif kind in ("Deployment", "StatefulSet", "DaemonSet", "Job"):
        pod = (spec.get("template") or {}).get("spec") or {}
    elif kind == "Pod":
        pod = spec
    else:
        continue
    for c in (pod.get("initContainers") or []) + (pod.get("containers") or []):
        images.add(c.get("image", ""))
if not images:
    sys.exit("ERROR: no images rendered")
for image in sorted(images):
    if not image.startswith(registry + "/") or "@" in image:
        sys.exit(f"ERROR: unexpected registry/digest: {image}")
    path = image[len(registry)+1:]
    if ":" not in path:
        sys.exit(f"ERROR: image lacks tag: {image}")
    repo, tag = path.rsplit(":", 1)
    if not repo or not tag or tag.lower() == "latest":
        sys.exit(f"ERROR: invalid image tag: {image}")
    result = subprocess.run(["aws", "ecr", "describe-images", "--region", region, "--registry-id", account, "--repository-name", repo, "--image-ids", f"imageTag={tag}", "--output", "json"], capture_output=True, text=True)
    if result.returncode:
        sys.exit(f"ERROR: image missing or inaccessible: {image}: {result.stderr.strip()}")
    print(f"Verified ECR image: {image}")
