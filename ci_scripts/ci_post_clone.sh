#!/bin/sh

# Exit on error (-e), undefined vars (-u), and pipeline failures (-o pipefail)
set -euo pipefail

# Skip macro fingerprint validation on Xcode Cloud
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES
