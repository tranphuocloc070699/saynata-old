# Needs macOS with Xcode and `brew install xcodegen`.
SIM ?= iPhone 16 Pro
DEST = 'platform=iOS Simulator,name=$(SIM)'
.PHONY: project check test
project:   ## generate App.xcodeproj from project.yml
	xcodegen generate --quiet
check: project   ## build + all tests (what CI runs)
	set -o pipefail && xcodebuild test -project App.xcodeproj -scheme App -destination $(DEST) -quiet | tail -40
test: project    ## one suite: make test S=NotesStoreTests
	set -o pipefail && xcodebuild test -project App.xcodeproj -scheme App -destination $(DEST) -only-testing:AppTests/$(S) -quiet | tail -40
