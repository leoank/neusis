#!/bin/sh
# neusis CLI installer.
#
#   curl -fsSL https://raw.githubusercontent.com/leoank/neusis/main/cli/install.sh | sh
#
# Environment overrides:
#   NEUSIS_VERSION      version to install (default: latest release)
#   NEUSIS_INSTALL_DIR  install directory (default: first writable of
#                       /usr/local/bin, $HOME/.local/bin)
#   NEUSIS_REPO         owner/repo (default: leoank/neusis)
set -eu

REPO="${NEUSIS_REPO:-leoank/neusis}"

err() {
	echo "install: $*" >&2
	exit 1
}

# --- detect platform ---------------------------------------------------
os=$(uname -s)
case "$os" in
	Linux) os=linux ;;
	Darwin) os=darwin ;;
	*) err "unsupported OS: $os (linux and darwin only)" ;;
esac

arch=$(uname -m)
case "$arch" in
	x86_64 | amd64) arch=amd64 ;;
	aarch64 | arm64) arch=arm64 ;;
	*) err "unsupported architecture: $arch" ;;
esac

# --- resolve version ---------------------------------------------------
version="${NEUSIS_VERSION:-}"
if [ -z "$version" ]; then
	version=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" |
		sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
	[ -n "$version" ] || err "could not determine the latest release; set NEUSIS_VERSION"
fi

# --- pick an install dir -----------------------------------------------
install_dir="${NEUSIS_INSTALL_DIR:-}"
if [ -z "$install_dir" ]; then
	for d in /usr/local/bin "$HOME/.local/bin"; do
		if [ -d "$d" ] && [ -w "$d" ]; then
			install_dir="$d"
			break
		fi
	done
	# Fall back to ~/.local/bin, creating it if needed.
	[ -n "$install_dir" ] || install_dir="$HOME/.local/bin"
fi
mkdir -p "$install_dir" || err "cannot create install dir: $install_dir"

# --- download + extract ------------------------------------------------
asset="neusis_${os}_${arch}.tar.gz"
url="https://github.com/${REPO}/releases/download/${version}/${asset}"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "Downloading neusis ${version} (${os}/${arch})…"
curl -fSL "$url" -o "$tmp/$asset" || err "download failed: $url"
tar -xzf "$tmp/$asset" -C "$tmp" || err "extract failed"

[ -f "$tmp/neusis" ] || err "archive did not contain the neusis binary"
install -m 0755 "$tmp/neusis" "$install_dir/neusis" 2>/dev/null ||
	{ cp "$tmp/neusis" "$install_dir/neusis" && chmod 0755 "$install_dir/neusis"; }

echo "Installed neusis to $install_dir/neusis"
case ":$PATH:" in
	*":$install_dir:"*) ;;
	*) echo "Note: $install_dir is not on your PATH." ;;
esac
"$install_dir/neusis" version >/dev/null 2>&1 && echo "Run 'neusis init' to get started."
