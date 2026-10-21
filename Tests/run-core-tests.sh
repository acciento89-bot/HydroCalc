#!/bin/bash
set -eu
HYDRO_TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hydro-project-tests.XXXXXX")"
trap 'rm -rf "$HYDRO_TEST_DIR"' EXIT
swiftc HydroCalc/HydroCalculator.swift HydroCalc/HydroProjects.swift Tests/ProjectTests.swift -o "$HYDRO_TEST_DIR/tests"
"$HYDRO_TEST_DIR/tests"
