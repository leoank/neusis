"""gclb — clone a remote git repo as a bare repo with worktrees.

Produces this layout:

    <repo>/
    ├── .git           # one-line pointer: `gitdir: .bare`
    ├── .bare/         # the bare repo (source of truth)
    └── <default>/     # initial worktree for the default branch

The bare repo is the source of truth; worktrees are cheap independent
checkouts you can add and remove without disturbing each other.
"""

# flake8: noqa
from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path


# Fetch refspec that makes `git fetch` populate `refs/remotes/origin/*`
# the way a non-bare clone would.
ORIGIN_FETCH_REFSPEC = "+refs/heads/*:refs/remotes/origin/*"


def parse_repo_name(url: str) -> str:
    """Extract the repository name from a git URL.

    Handles SSH (`git@host:org/repo[.git]`), HTTPS
    (`https://host/org/repo[.git]`), and `ssh://…` URLs, with an
    optional trailing slash. Returns the last path segment with any
    `.git` suffix stripped.
    """
    last = re.split(r"[/:]", url.rstrip("/"))[-1]
    if not last:
        raise ValueError(f"Could not parse a repository name from {url!r}.")
    return last[:-4] if last.endswith(".git") else last


def git(
    *args: str,
    cwd: Path | None = None,
    capture: bool = False,
) -> subprocess.CompletedProcess[str]:
    """Run `git` with check=True and text mode. Capture stdout if asked."""
    return subprocess.run(
        ["git", *args],
        cwd=cwd,
        check=True,
        text=True,
        capture_output=capture,
    )


def default_branch(repo_root: Path) -> str:
    """Read the default branch from the local HEAD.

    `git clone --bare` sets `<bare>/HEAD` to the remote's default
    branch, so we don't need another network round-trip.
    """
    result = git("symbolic-ref", "--short", "HEAD", cwd=repo_root, capture=True)
    branch = result.stdout.strip()
    if not branch:
        raise RuntimeError("HEAD has no symbolic ref; cannot determine default branch.")
    return branch


def write_gitfile(repo_root: Path, bare_dir: Path) -> None:
    """Write `<repo_root>/.git` with a relative `gitdir:` pointer."""
    try:
        target = bare_dir.relative_to(repo_root)
    except ValueError:
        # Bare dir lives outside repo_root (user passed an absolute
        # -l elsewhere); fall back to an absolute pointer.
        target = bare_dir
    (repo_root / ".git").write_text(f"gitdir: {target}\n")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Clone a git repo as a bare repo with a worktree per branch.",
        epilog=(
            "Examples:\n"
            "  gclb git@github.com:org/repo.git\n"
            "  gclb https://github.com/org/repo.git -l ~/code/repo/.bare\n"
            "  gclb git@github.com:org/repo.git --depth 1 --filter=blob:none\n"
            "  gclb git@github.com:org/repo.git -- --recurse-submodules\n"
            "\n"
            "Any flag gclb doesn't recognise is passed verbatim to `git clone`. "
            "Use `--` before such flags if you want to be explicit."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("url", help="Git URL to clone (any form git itself accepts).")
    parser.add_argument(
        "-l",
        "--location",
        help=(
            "Path to the bare directory. Defaults to `<repo>/.bare/` "
            "under the current directory."
        ),
    )
    return parser


def main() -> int:
    # `parse_known_args` lets unrecognised flags fall through to
    # `extra_git_args` so callers can tack on arbitrary `git clone`
    # options (`--depth`, `--filter`, `--branch`, `--recurse-submodules`,
    # …) without us having to mirror them.
    args, extra_git_args = build_parser().parse_known_args()
    # argparse keeps a leading `--` separator in the remainder on some
    # Python versions; drop it.
    if extra_git_args and extra_git_args[0] == "--":
        extra_git_args = extra_git_args[1:]

    if shutil.which("git") is None:
        print("error: `git` not found on PATH.", file=sys.stderr)
        return 1

    try:
        repo_name = parse_repo_name(args.url)
    except ValueError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1

    bare = (Path(args.location) if args.location else Path(repo_name) / ".bare").absolute()
    repo_root = bare.parent
    gitfile = repo_root / ".git"

    # Refuse to clobber an existing checkout.
    for path in (bare, gitfile):
        if path.exists():
            print(f"error: {path} already exists; refusing to overwrite.", file=sys.stderr)
            return 1

    repo_root.mkdir(parents=True, exist_ok=True)

    try:
        print(f"==> Cloning bare repository to {bare}")
        # Extra args go BEFORE the URL/dir positionals so they're
        # interpreted as `git clone` options, not as URLs.
        git("clone", "--bare", *extra_git_args, args.url, str(bare))

        print(f"==> Writing {gitfile}")
        write_gitfile(repo_root, bare)

        print("==> Configuring origin fetch refspec")
        git("config", "--add", "remote.origin.fetch", ORIGIN_FETCH_REFSPEC, cwd=repo_root)

        print("==> Discovering default branch")
        branch = default_branch(repo_root)

        print(f"==> Adding worktree for {branch!r}")
        git("worktree", "add", branch, branch, cwd=repo_root)
    except subprocess.CalledProcessError as e:
        print(
            f"error: git command failed (exit {e.returncode}): {' '.join(e.cmd)}",
            file=sys.stderr,
        )
        return e.returncode

    print(f"\nDone. cd {repo_root / branch}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
