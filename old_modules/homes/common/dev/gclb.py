# flake8: noqa
import re
from pathlib import Path
from subprocess import run


def parse_git_repo(url: str) -> str:
    """
    Parses a Git URL and returns repo name.

    Args:
        url (str): The Git URL to parse.

    Returns:
        dict: A dictionary containing the scheme, host, and path,
              or None if the URL is invalid.
    """
    match = re.search(
        r"([^/]+(.git)?)$",
        url,
    )
    if match:
        return match.group(0).replace(".git", "")
    else:
        raise ValueError("Unable to parse a repository from the url.")


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="A helper for cloning bare repos.")
    parser.add_argument("url", help="The Git URL to clone.")
    parser.add_argument("-l", "--location", help="Location for cloning the bare repo")

    args = parser.parse_args()
    repo_name = parse_git_repo(args.url)

    location = args.location or f"{repo_name}/.bare"
    location = Path(location)

    # Exec git
    print(f"Cloning bare repository to {location}...")
    run(["git", "clone", "--bare", args.url, str(location)], check=True)
    print("Setting .git file contents...")
    location.parent.joinpath(".git").write_text(f"gitdir: {location.name}")
    print("Adjusting origin fetch location...")
    run(
        [
            "git",
            "config",
            "--add",
            "remote.origin.fetch",
            "+refs/heads/*:refs/remotes/origin/*",
        ],
        cwd=location.parent,
    )
    print("Creating default branch from remote...")
    branch_run = run(
        ["git", "remote", "show", "origin"],
        capture_output=True,
        cwd=location.parent,
        check=True,
    )
    git_out_match = re.search(r"HEAD branch: ([^ ]+)", branch_run.stdout.__str__())
    assert git_out_match is not None
    branch = git_out_match.group(0).replace("HEAD branch: ", "").replace("\\n", "")
    run(["git", "worktree", "add", branch, branch], cwd=location.parent, check=True)
    print("Success.")
