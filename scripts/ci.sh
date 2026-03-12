#!/bin/bash
# CI script for formatting and linting Elixir code.
# Defaults to fix/write mode for the formatter.
# Use --check to run in read-only verification mode (fails CI if issues found).

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default: fix mode (formatter will write changes)
CHECK_ONLY=false

# Parse arguments
for arg in "$@"; do
  case $arg in
    --check)
      CHECK_ONLY=true
      ;;
    --help|-h)
      echo "Usage: $0 [--check|--help]"
      echo ""
      echo "  --check    Run in read-only mode. Formatter checks without modifying files."
      echo "             Linter runs normally and exits with error if issues found."
      echo "  --help, -h Show this help message"
      echo ""
      echo "Default (no flags):"
      echo "  Formatter writes fixes to files."
      echo "  Linter checks and reports issues (read-only)."
      exit 0
      ;;
    *)
      echo -e "${RED}Error: Unknown argument '$arg'${NC}"
      echo "Run '$0 --help' for usage."
      exit 1
      ;;
  esac
done

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

echo -e "${GREEN}=== Running CI Checks ===${NC}"
echo "Project root: $PROJECT_ROOT"
echo "Mode: $([ "$CHECK_ONLY" = true ] && echo 'check (read-only)' || echo 'fix (write for formatter)')"
echo ""

# Ensure dependencies are installed
echo -e "${YELLOW}Ensuring dependencies are available...${NC}"
mix deps.get 2>&1 | grep -v "already cached" | grep -v "already up to date" || true

# Run formatter
echo ""
echo -e "${GREEN}=== Formatter ===${NC}"
if [ "$CHECK_ONLY" = true ]; then
  echo "Running: mix format --check-formatted"
  if ! mix format --check-formatted; then
    echo ""
    echo -e "${RED}❌ Formatting check failed!${NC}"
    echo "Run '$0' (without --check) to auto-format the code, or run 'mix format' manually."
    exit 1
  fi
else
  echo "Running: mix format"
  if ! mix format; then
    echo ""
    echo -e "${RED}❌ Formatter failed!${NC}"
    exit 1
  fi
fi
echo -e "${GREEN}✅ Formatter passed${NC}"

# Run linter (Credo)
echo ""
echo -e "${GREEN}=== Linter ===${NC}"
echo "Running: mix credo"

# Use strict mode for CI - treat warnings as errors
CREDO_FLAGS="--strict"

if ! mix credo $CREDO_FLAGS; then
  echo ""
  echo -e "${RED}❌ Linter failed!${NC}"
  echo "Review the issues above and fix them manually."
  echo "For more details, run: mix credo"
  exit 1
fi
echo -e "${GREEN}✅ Linter passed${NC}"

# All checks passed
echo ""
echo -e "${GREEN}=== All CI checks passed! ===${NC}"
exit 0
