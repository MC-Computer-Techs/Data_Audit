#!/bin/bash

echo "Starting setup for Data Audit App..."

# 1. Check if uv is installed, if not, offer to install or fallback to pip
if ! command -v uv &> /dev/null; then
    echo "uv is not installed on this system."
    echo "You can install it by running: curl -LsSf https://astral.sh/uv/install.sh | sh"
    echo "Falling back to standard python venv and pip..."
    
    python3 -m venv .venv
    source .venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
else
    echo "Found uv! Creating a virtual environment..."
    uv venv
    source .venv/bin/activate
    
    echo "Installing requirements using uv pip..."
    uv pip install -r requirements.txt
fi

echo "======================================"
echo "Setup complete!"
echo "To run the application, make sure your environment is activated:"
echo "source .venv/bin/activate"
echo "Then start the app:"
echo "streamlit run src/app.py"
echo "======================================"
