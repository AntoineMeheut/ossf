#!/bin/sh
set -eu
# An import smoke check also works for libraries with no command-line interface.
# Replace this hook with a real startup/HTTP check when deploying a service.
docker run --rm --entrypoint python "$APP_IMAGE" -c 'import importlib, os; importlib.import_module(os.environ["PYTHON_MODULE"])'
