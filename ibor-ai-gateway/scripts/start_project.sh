#!/bin/bash
set -euo pipefail

PROJECT_ROOT="/Users/kartikmakker/Kartik_Workspace/middleoffice-ibor"
PROJECT_DIR="$PROJECT_ROOT/ai-gateway"
VENV_PATH="$PROJECT_DIR/.venv"
IDEA_NEW_WINDOW=${1:-false}

# Disable Conda base auto-activation (runs once; safe to repeat)
if command -v conda >/dev/null 2>&1; then
  conda config --set auto_activate_base which  >/dev/null
fi

# Ensure the virtual environment exists
if [ ! -d "$VENV_PATH" ]; then
  echo "Creating virtual environment at $VENV_PATH"
  uv venv "$VENV_PATH" --python 3.13
fi

echo "Activating $VENV_PATH"
# shellcheck source=/dev/null
source "$VENV_PATH/bin/activate"

cd "$PROJECT_DIR"

echo "Syncing project dependencies via uv"
uv sync --python "$VENV_PATH/bin/python"

echo "Using Python interpreter: $(which python)"
echo "openai packages:"
"$VENV_PATH/bin/pip" list | grep openai || echo "  (openai packages not installed)"

if [ "$IDEA_NEW_WINDOW" = "true" ] && command -v idea >/dev/null 2>&1; then
  echo "Opening IntelliJ IDEA in new window..."
  idea "$PROJECT_ROOT" --new-window
else
  echo "To open IntelliJ IDEA manually, run:"
  echo "  idea $PROJECT_ROOT"
fi

echo "Environment ready. Prompt should display (.venv)."
exec "$SHELL"