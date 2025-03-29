# NixOS/Home-Manager Configuration Guidelines

## Build Commands
- NixOS: `nixos-rebuild switch --flake .#<machine>` (e.g., `.#karkinos`)
- macOS: `darwin-rebuild switch --flake .#<machine>` (e.g., `.#darwin001`)
- Development shell: `nix develop`

## Test/Lint Commands
- Nix lint: `statix check`
- Nix format: `nixfmt-rfc-style`
- Python test: `python -m pytest [path/to/test.py::test_function_name]`
- Python lint/format: `ruff check` / `ruff format`

## Code Style Guidelines
- **Nix**: Use CamelCase for attribute names, snake_case for variables
- **Python**: Follow PEP 8, use type annotations
- **Formatting**: Let formatters handle style (nixfmt-rfc-style for Nix, ruff for Python)
- **Error handling**: Use descriptive error messages, prefer option types over exceptions
- **Imports**: Group imports (stdlib, third-party, local), sort alphabetically
- **Naming**: Use descriptive names reflecting purpose, not implementation

## Repository Structure
- `machines/`: NixOS configurations
- `homes/`: Home-manager configurations
- `pkgs/`: Custom packages
- `templates/`: Project templates