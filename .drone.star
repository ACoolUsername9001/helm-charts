config = {
    "branches": [
        "master",
    ],
    # if this changes, also the kubeVersion in the Chart.yaml needs to be changed
    "kubernetesVersions": [
        "1.20.0",
        "1.21.0",
        "1.22.0",
        "1.23.0",
        "1.24.0",
    ],
}

def main(ctx):
    # return linting(ctx) + documentation(ctx) + checkStarlark()
    return linting(ctx) + checkStarlark()

def linting(ctx):
    pipelines = []

    kubeconform_steps = []

    for version in config["kubernetesVersions"]:
        kubeconform_steps.append(
            {
                "name": "kubeconform-%s" % version,
                "image": "ghcr.io/yannh/kubeconform:master",
                "entrypoint": [
                    "/kubeconform",
                    "-kubernetes-version",
                    "%s" % version,
                    "-summary",
                    "-strict",
                    "ocis-ci-templated.yaml",
                ],
            },
        )

    result = {
        "kind": "pipeline",
        "type": "docker",
        "name": "lint charts/owncloud",
        "steps": [
            {
                "name": "helm lint",
                "image": "alpine/helm:latest",
                "commands": [
                    "helm lint charts/owncloud",
                ],
            },
            {
                "name": "helm template",
                "image": "alpine/helm:latest",
                "commands": [
                    "helm template charts/owncloud -f charts/owncloud/values-ci-testing.yaml > ocis-ci-templated.yaml",
                ],
            },
            {
                "name": "kube-linter",
                "image": "stackrox/kube-linter:latest",
                "entrypoint": [
                    "/kube-linter",
                    "lint",
                    "ocis-ci-templated.yaml",
                ],
            },
        ] + kubeconform_steps,
        "depends_on": [],
        "trigger": {
            "ref": [
                "refs/pull/**",
            ],
        },
    }

    for branch in config["branches"]:
        result["trigger"]["ref"].append("refs/heads/%s" % branch)

    pipelines.append(result)

    return pipelines

def documentation(ctx):
    result = {
        "kind": "pipeline",
        "type": "docker",
        "name": "documentation",
        "steps": [
            {
                "name": "helm-docs-readme",
                "image": "jnorwood/helm-docs:v1.11.0",
                "entrypoint": [
                    "/usr/bin/helm-docs",
                    "--template-files=README.md.gotmpl",
                    "--output-file=README.md",
                ],
            },
            {
                "name": "helm-docs-values-table-adoc",
                "image": "jnorwood/helm-docs:v1.11.0",
                "entrypoint": [
                    "/usr/bin/helm-docs",
                    "--template-files=charts/owncloud/docs/templates/values-desc-table.adoc.gotmpl",
                    "--output-file=docs/values-desc-table.adoc",
                ],
            },
            {
                "name": "helm-docs-kube-versions-adoc",
                "image": "jnorwood/helm-docs:v1.11.0",
                "entrypoint": [
                    "/usr/bin/helm-docs",
                    "--template-files=charts/owncloud/docs/templates/kube-versions.adoc.gotmpl",
                    "--output-file=kube-versions.adoc",
                ],
            },
            {
                "name": "gomplate-values-adoc",
                "image": "hairyhenderson/gomplate:v3.10.0-alpine",
                "enviornment": {
                    "ASSUME_NO_MOVING_GC_UNSAFE_RISK_IT_WITH": "go1.18",
                },
                "entrypoint": [
                    "/bin/gomplate",
                    "--file=charts/owncloud/docs/templates/values.adoc.yaml.gotmpl",
                    "--out=charts/owncloud/docs/values.adoc.yaml",
                ],
            },
            {
                "name": "check-unchanged",
                "image": "owncloudci/alpine",
                "commands": [
                    "git diff --exit-code",
                ],
            },
        ],
        "depends_on": [],
        "trigger": {
            "ref": [
                "refs/pull/**",
            ],
        },
    }

    for branch in config["branches"]:
        result["trigger"]["ref"].append("refs/heads/%s" % branch)

    return [result]

def checkStarlark():
    result = {
        "kind": "pipeline",
        "type": "docker",
        "name": "check-starlark",
        "steps": [
            {
                "name": "format-check-starlark",
                "image": "owncloudci/bazel-buildifier:latest",
                "commands": [
                    "buildifier --mode=check .drone.star",
                ],
            },
            {
                "name": "show-diff",
                "image": "owncloudci/bazel-buildifier:latest",
                "commands": [
                    "buildifier --mode=fix .drone.star",
                    "git diff",
                ],
                "when": {
                    "status": [
                        "failure",
                    ],
                },
            },
        ],
        "depends_on": [],
        "trigger": {
            "ref": [
                "refs/pull/**",
            ],
        },
    }

    for branch in config["branches"]:
        result["trigger"]["ref"].append("refs/heads/%s" % branch)

    return [result]
