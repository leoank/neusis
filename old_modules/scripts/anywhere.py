#!/usr/bin/env -S uv run --script

# /// script
# dependencies = []
# ///

import argparse
import os
import stat
import sys
from pathlib import Path
from subprocess import CalledProcessError, run


def decrypt_age_file(
    age_file_path: Path, key_path: Path = Path("/etc/ssh/ssh_host_ed25519_key")
) -> str:
    """Decrypt an age-encrypted file using agenix."""
    cmd = ["age", "--decrypt", "-i", str(key_path), str(age_file_path)]
    try:
        out = run(cmd, capture_output=True, text=True, check=True)
        return out.stdout
    except CalledProcessError as e:
        print(f"Error decrypting {age_file_path}: {e.stderr}", file=sys.stderr)
        raise


def write_to_temp(
    data: str,
    file_path: Path,
    temp_folder: Path,
    extra_files_folder: Path,
    remove_suffix: bool = False,
):
    """Write decrypted data to a temporary file maintaining directory structure."""
    # Calculate relative path from the extra_files_folder root
    relative_path = file_path.relative_to(extra_files_folder)

    # Remove .age extension to get the original file path
    suffix = "" if remove_suffix else file_path.suffix
    target_path = temp_folder / relative_path.with_suffix(suffix)

    # Create parent directories if they don't exist
    target_path.parent.mkdir(parents=True, exist_ok=True)

    # Write the decrypted content
    target_path.write_text(data)
    print(f"Written decrypted content to: {target_path}")


def fix_ssh_key_permissions(temp_folder: Path):
    """Fix permissions for SSH keys in the temp folder."""
    ssh_key_patterns = ["**/ssh_host_*_key", "**/ssh_host_*_key.pub"]

    for pattern in ssh_key_patterns:
        for key_file in temp_folder.glob(pattern):
            if key_file.suffix == ".pub":
                # Public keys: 644 (readable by all, writable by owner)
                key_file.chmod(
                    stat.S_IRUSR | stat.S_IWUSR | stat.S_IRGRP | stat.S_IROTH
                )
                print(f"Set permissions 644 for public key: {key_file}")
            else:
                # Private keys: 600 (readable/writable by owner only)
                key_file.chmod(stat.S_IRUSR | stat.S_IWUSR)
                print(f"Set permissions 600 for private key: {key_file}")


def create_root_structure(
    extra_files_folder: Path,
    temp_folder: Path = Path("/tmp/neusis_anywhere_temp"),
    decryption_key_path=Path("/etc/ssh/ssh_host_ed25519_key"),
):
    """Create a root file structure by decrypting age files and placing them in temp folder."""
    # Create temp folder if it doesn't exist
    temp_folder.mkdir(parents=True, exist_ok=True)

    # Find all .age files recursively
    files_list = [file for file in extra_files_folder.rglob("*") if not file.is_dir()]
    age_files_list = [file for file in files_list if file.suffix == ".age"]
    filtered_files_list = [file for file in files_list if not file.suffix == ".age"]

    if not age_files_list:
        print(f"No .age files found in {extra_files_folder}")
        return

    print(f"Found {len(age_files_list)} age files to decrypt")

    for age_file in age_files_list:
        try:
            print(f"Decrypting: {age_file}")
            decrypted_str = decrypt_age_file(age_file, decryption_key_path)
            write_to_temp(
                decrypted_str, age_file, temp_folder, extra_files_folder, True
            )
        except Exception as e:
            print(f"Failed to process {age_file}: {e}", file=sys.stderr)
            continue

    for file in filtered_files_list:
        # TODO: Hack for now, improve later
        write_to_temp(file.read_text(), file, temp_folder, extra_files_folder)

    # Fix SSH key permissions
    fix_ssh_key_permissions(temp_folder)

    print(f"Root structure created in: {temp_folder}")


def run_nixos_anywhere(
    target_host: str,
    flake: str,
    extra_files_folder: Path,
    temp_folder: Path = Path("/tmp/neusis_anywhere_temp"),
    decryption_key_path: Path = Path("/etc/ssh/ssh_host_ed25519_key"),
    **nixos_anywhere_args,
):
    """Run nixos-anywhere with decrypted extra files."""
    # Create root structure with decrypted files
    create_root_structure(extra_files_folder, temp_folder, decryption_key_path)

    # Build nixos-anywhere command
    cmd = ["nixos-anywhere"]

    # Add flake
    cmd.extend(["--flake", flake])

    # Add extra files
    cmd.extend(["--extra-files", str(temp_folder)])

    # Add ssh -t flag
    # https://github.com/nix-community/nixos-anywhere/issues/178
    cmd.append("-t")

    # Add other nixos-anywhere arguments
    for key, value in nixos_anywhere_args.items():
        if value is True:
            cmd.append(f"--{key.replace('_', '-')}")
        elif value is not None:
            if key == "identity_file" or key == "i":
                cmd.extend(["-i", str(value)])
            else:
                cmd.extend([f"--{key.replace('_', '-')}", str(value)])

    # Add target host
    cmd.append(target_host)

    print(f"Running command: {' '.join(cmd)}")

    try:
        result = run(cmd, check=True)
        print("nixos-anywhere completed successfully")
        return result
    except CalledProcessError as e:
        print(f"nixos-anywhere failed with exit code {e.returncode}", file=sys.stderr)
        raise


def main():
    """CLI interface for the anywhere script."""
    parser = argparse.ArgumentParser(
        description="Decrypt age files and run nixos-anywhere or just create root structure"
    )

    # Subcommands
    subparsers = parser.add_subparsers(dest="command", help="Available commands")

    # Decrypt-only mode (original functionality)
    decrypt_parser = subparsers.add_parser(
        "decrypt", help="Only decrypt files and create root structure"
    )
    decrypt_parser.add_argument(
        "extra_files_folder", type=Path, help="Path to folder containing .age files"
    )
    decrypt_parser.add_argument(
        "--temp-folder",
        type=Path,
        default=Path("/tmp/neusis_anywhere_temp"),
        help="Temporary folder to create root structure (default: /tmp/neusis_anywhere_temp)",
    )
    decrypt_parser.add_argument(
        "--key",
        type=Path,
        default=Path("/etc/ssh/ssh_host_ed25519_key"),
        help="Key to use for decryption (default: /etc/ssh/ssh_host_ed25519_key)",
    )

    # nixos-anywhere wrapper mode
    deploy_parser = subparsers.add_parser(
        "deploy", help="Deploy using nixos-anywhere with decrypted extra files"
    )
    deploy_parser.add_argument("target_host", help="SSH target host to deploy onto")
    deploy_parser.add_argument(
        "--flake", "-f", required=True, help="Flake URI (e.g., .#machine-name)"
    )
    deploy_parser.add_argument(
        "extra_files_folder", type=Path, help="Path to folder containing .age files"
    )
    deploy_parser.add_argument(
        "--temp-folder",
        type=Path,
        default=Path("/tmp/neusis_anywhere_temp"),
        help="Temporary folder to create root structure (default: /tmp/neusis_anywhere_temp)",
    )
    deploy_parser.add_argument(
        "--key",
        type=Path,
        default=Path("/etc/ssh/ssh_host_ed25519_key"),
        help="Key to use for decryption (default: /etc/ssh/ssh_host_ed25519_key)",
    )

    # Common nixos-anywhere options
    deploy_parser.add_argument("--ssh-port", "-p", type=int, help="SSH port")
    deploy_parser.add_argument(
        "--identity-file", "-i", type=Path, help="SSH private key file"
    )
    deploy_parser.add_argument(
        "--copy-host-keys", action="store_true", help="Copy existing host keys"
    )
    deploy_parser.add_argument(
        "--print-build-logs", "-L", action="store_true", help="Print full build logs"
    )
    deploy_parser.add_argument(
        "--debug", action="store_true", help="Enable debug output"
    )
    deploy_parser.add_argument(
        "--vm-test", action="store_true", help="Test in VM without installing"
    )
    deploy_parser.add_argument(
        "--build-on-remote", action="store_true", help="Build on remote machine"
    )
    deploy_parser.add_argument(
        "--no-substitute-on-destination",
        action="store_true",
        help="Disable substitute on destination",
    )
    deploy_parser.add_argument(
        "--kexec", type=Path, help="Use another kexec tarball to bootstrap NixOS"
    )

    args = parser.parse_args()

    # Handle case where no subcommand is provided (backward compatibility)
    if args.command is None:
        # Try to parse as old format (just extra_files_folder as positional arg)
        if len(sys.argv) > 1 and not sys.argv[1].startswith("-"):
            # Create a namespace with the old arguments
            import types

            args = types.SimpleNamespace()
            args.command = "decrypt"
            args.extra_files_folder = Path(sys.argv[1])
            args.temp_folder = Path("/tmp/neusis_anywhere_temp")
            args.key = Path("/etc/ssh/ssh_host_ed25519_key")

            # Parse remaining args manually for backward compatibility
            for i in range(2, len(sys.argv)):
                if sys.argv[i] == "--temp-folder" and i + 1 < len(sys.argv):
                    args.temp_folder = Path(sys.argv[i + 1])
                elif sys.argv[i] == "--key" and i + 1 < len(sys.argv):
                    args.key = Path(sys.argv[i + 1])
        else:
            parser.print_help()
            sys.exit(1)

    # Validate input folder exists (for decrypt and deploy commands)
    if args.command in ["decrypt", "deploy"]:
        if not args.extra_files_folder.exists():
            print(f"Error: {args.extra_files_folder} does not exist", file=sys.stderr)
            sys.exit(1)

        if not args.extra_files_folder.is_dir():
            print(
                f"Error: {args.extra_files_folder} is not a directory", file=sys.stderr
            )
            sys.exit(1)

        if not args.key.exists():
            print(f"Error: Key {args.key} does not exist", file=sys.stderr)
            sys.exit(1)

    try:
        if args.command == "decrypt":
            create_root_structure(
                args.extra_files_folder.resolve(),
                args.temp_folder.resolve(),
                args.key.resolve(),
            )
        elif args.command == "deploy":
            # Prepare nixos-anywhere arguments
            nixos_anywhere_args = {}
            if hasattr(args, "ssh_port") and args.ssh_port:
                nixos_anywhere_args["ssh_port"] = args.ssh_port
            if hasattr(args, "identity_file") and args.identity_file:
                nixos_anywhere_args["i"] = args.identity_file
            if hasattr(args, "copy_host_keys") and args.copy_host_keys:
                nixos_anywhere_args["copy_host_keys"] = True
            if hasattr(args, "print_build_logs") and args.print_build_logs:
                nixos_anywhere_args["print_build_logs"] = True
            if hasattr(args, "debug") and args.debug:
                nixos_anywhere_args["debug"] = True
            if hasattr(args, "vm_test") and args.vm_test:
                nixos_anywhere_args["vm_test"] = True
            if hasattr(args, "build_on_remote") and args.build_on_remote:
                nixos_anywhere_args["build_on_remote"] = True
            if (
                hasattr(args, "no_substitute_on_destination")
                and args.no_substitute_on_destination
            ):
                nixos_anywhere_args["no_substitute_on_destination"] = True
            if hasattr(args, "kexec") and args.kexec:
                nixos_anywhere_args["kexec"] = args.kexec

            run_nixos_anywhere(
                target_host=args.target_host,
                flake=args.flake,
                extra_files_folder=args.extra_files_folder.resolve(),
                temp_folder=args.temp_folder.resolve(),
                decryption_key_path=args.key.resolve(),
                **nixos_anywhere_args,
            )
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
