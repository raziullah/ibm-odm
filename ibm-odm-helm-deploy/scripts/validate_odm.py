#!/usr/bin/env python3
"""Fail-closed IBM ODM Dev chart compatibility checks (requires PyYAML)."""
import sys
import yaml

def fail(msg):
    raise SystemExit('ODM validation FAILED: ' + msg)

def load(path):
    with open(path, encoding='utf-8') as fh:
        return list(yaml.safe_load_all(fh))

def path_exists(root, path):
    for key in path.split('.'):
        if not isinstance(root, dict) or key not in root:
            return False
        root = root[key]
    return True

def leaf_paths(root, prefix=''):
    if isinstance(root, dict):
        for k, v in root.items():
            yield from leaf_paths(v, prefix + '.' + str(k) if prefix else str(k))
    else:
        yield prefix

mode, source, overrides = sys.argv[1:4]
values = load(overrides)[0]
if mode == 'schema':
    defaults = load(source)[0]
    if not isinstance(defaults, dict):
        fail('chart defaults are not a mapping')
    # Helm silently ignores unknown keys; reject unrecognized override paths.
    missing = [key for key in leaf_paths(values) if not path_exists(defaults, key)]
    if missing:
        fail('Dev override keys absent from chart defaults (map to real chart keys): ' + ', '.join(missing))
    print('ODM schema check passed: all Dev override paths exist in chart defaults')
elif mode == 'rendered':
    docs = [d for d in load(source) if isinstance(d, dict)]
    workloads = []
    for d in docs:
        kind = d.get('kind')
        spec = d.get('spec') or {}
        if kind in ('Deployment', 'StatefulSet', 'DaemonSet', 'Job'):
            pod = (spec.get('template') or {}).get('spec') or {}
        elif kind == 'CronJob':
            pod = (((spec.get('jobTemplate') or {}).get('spec') or {}).get('template') or {}).get('spec') or {}
        elif kind == 'Pod':
            pod = spec
        else:
            continue
        name = (d.get('metadata') or {}).get('name', '?')
        workloads.append(name)
        selectors = pod.get('nodeSelector') or {}
        if selectors.get('kubernetes.io/arch') != 'amd64' or selectors.get('workload') != 'ibm':
            fail(f'{kind}/{name}: missing amd64 and workload=ibm nodeSelector')
        tolerations = pod.get('tolerations') or []
        if not any(t.get('key') == 'workload' and t.get('value') == 'ibm' and t.get('effect') == 'NoSchedule' and t.get('operator', 'Equal') == 'Equal' for t in tolerations):
            fail(f'{kind}/{name}: missing workload=ibm:NoSchedule toleration')
        containers = (pod.get('initContainers') or []) + (pod.get('containers') or [])
        if not containers:
            fail(f'{kind}/{name}: no containers')
        for container in containers:
            image = container.get('image', '')
            if not image.startswith('986454734902.dkr.ecr.ap-southeast-2.amazonaws.com/') or ':' not in image:
                fail(f'{kind}/{name}: image is not an explicitly tagged image in approved ECR: {image}')
        # ECR authentication is supplied by the worker node IAM credential provider.
        # An optional imagePullSecret is not required and short-lived ECR tokens must not be persisted.
    if not workloads:
        fail('no ODM pod workloads rendered')
    # TLS must be demonstrably configured, not merely present as an unused Helm value.
    # Verify that the rendered JDBC/DB configuration actually enables TLS.
    serialized = yaml.safe_dump_all(docs).lower()
    if not any(token in serialized for token in ('sslmode=require', 'sslmode=verify-ca', 'sslmode=verify-full', 'sslmode: require', 'sslmode: verify-full', 'sslmode: verify-ca', 'ssl=true')):
        fail('no PostgreSQL TLS setting found in rendered manifests; inspect chart JDBC configuration')
    print('ODM rendered checks passed for:', ', '.join(workloads))
else:
    fail('unknown validation mode')
