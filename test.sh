#!/bin/bash
# Run menu bar regression tests without an Xcode test target.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .build/tests
sources=(
  MenuClock/Models/AppSettings.swift
  MenuClock/Models/WorldClock.swift
  MenuClock/Managers/SettingsManager.swift
  MenuClock/Managers/TimeFormatting.swift
  MenuClock/Managers/ClockTicker.swift
  MenuClock/Managers/CityDatabase.swift
  MenuClock/Managers/WeatherManager.swift
  MenuClock/ViewModels/MenuBarViewModel.swift
)
swiftc -sdk "$(xcrun --show-sdk-path)" -target arm64-apple-macos13.0 \
  -parse-as-library "${sources[@]}" Tests/MenuBarTests.swift \
  -o .build/tests/MenuClockRegressionTests
.build/tests/MenuClockRegressionTests
