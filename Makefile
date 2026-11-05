.DEFAULT_GOAL := help

ENV_FILE ?= .env
FLUTTER_ARGS ?=
FLUTTER ?= flutter
PYTHON ?= python3

.PHONY: help env-check run build-apk-debug build-apk build-appbundle build-ios

help:
	@echo 'make env-check       Validate the public app configuration in .env'
	@echo 'make run             Run Flutter with .env (FLUTTER_ARGS="-d <device-id>")'
	@echo 'make build-apk-debug Build an Android debug APK'
	@echo 'make build-apk       Build an Android arm64 release APK'
	@echo 'make build-appbundle Build an Android arm64/x64 release App Bundle'
	@echo 'make build-ios       Build iOS without signing (macOS / Xcode required)'
	@echo 'Override the configuration file with ENV_FILE=.env.staging'

env-check:
	@$(PYTHON) scripts/check_env.py "$(ENV_FILE)"

run: env-check
	$(FLUTTER) run --dart-define-from-file="$(ENV_FILE)" $(FLUTTER_ARGS)

build-apk-debug: env-check
	$(FLUTTER) build apk --debug --dart-define-from-file="$(ENV_FILE)" $(FLUTTER_ARGS)

build-apk: env-check
	$(FLUTTER) build apk --release --target-platform android-arm64 --dart-define-from-file="$(ENV_FILE)" $(FLUTTER_ARGS)

build-appbundle: env-check
	$(FLUTTER) build appbundle --release --target-platform android-arm64,android-x64 --dart-define-from-file="$(ENV_FILE)" $(FLUTTER_ARGS)

build-ios: env-check
	$(FLUTTER) build ios --no-codesign --dart-define-from-file="$(ENV_FILE)" $(FLUTTER_ARGS)
