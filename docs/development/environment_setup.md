# Environment Setup Guide

**Purpose**: This document provides comprehensive guidance for creating and managing different types of environments in the Neusis system. It covers both general Nix environments and Python-specific virtual environments, explaining when to use each type and how to manage them effectively.

## Overview

In the Neusis system, you can create different types of environments:

1. General Nix environments for any type of project
2. Python-specific virtual environments for Python projects

Each type serves different needs and has its own management approach.

## General Nix Environments

`homes/<username>/home.nix` describes the base environment for your user account (e.g. programs available specifically to your user account, dotfiles, etc.).

For a given project, you may want to create a separate project-specific environment with additional tools. For this you can create a new environment (nix shell) that is specific to the project.

### Creating from Template

In your home folder run:

```bash
nix flake new -t github:leoank/neusis#pythonml <project_name>
```

This will create a new environment using the template in `templates/pythonml`.

`cd` into `<project_name>`

You may edit the `flake.nix` file to include any additional programs you wish. Since the template creates a python project, there is no need to specify any python-specific packages (packages from PyPI) in the `flake.nix`, as those will instead be handled by `uv` and go in `pyproject.toml` instead.

To activate the virtual environment, from within the `<project_name>` directory run: `nix develop .`

"Activating" the virtual environment, in nix parlance, means you are put into a new "nix shell".

You can verify this by running:

```bash
echo $VIRTUAL_ENV
```

Which will show something like:

```
> /home/<username>/<project_name>/.venv
```

### Editing the Shell

If you want to edit the shell (not the `uv` environment, but the nix shell), you will need to edit the `flake.nix` file.

This requires a basic understanding of the [nix language](https://nix.dev/manual/nix/2.24/language/index.html).

## Python Virtual Environments

We normally want to create a separate virtual environment for each project (repository). Navigate to the root of your project repo, and create a new base virtual environment using Ank's template:

```bash
nix flake new -t github:leoank/neusis#pythonml axiom-env
```

This folder now looks like a normal Python project, with a pyproject.toml file, etc. The difference from a normal Python project is that it won't work without the flake.nix file. With Nix, we build a new shell from scratch, based on exactly we need inside of that shell. Since Nix is declarative, it has an internal map of where different software and packages are installed and what depends on what. When you run 'nix develop .', it builds a whole virtual environment with the specified software down to the base OS so that everything is where it's supposed to be and there are no dependency conflicts. Each software/package is only installed on Nix in one location, so you are really just linking to it and that's why this is so fast - we aren't re-downloading or installing anything. In contrast, with conda or mamba, each user must download and install each Python package separately, and sometimes separately for each virtual environment that they create. 

### First-Time Setup

To activate the virtual environment for the first time:

```bash
git init
git add .

nix develop .
```

If you are using bash, you should see (.venv) after your shell. If you are using something else like zsh, your shell should look different now. 

While inside of axiom-env (or whatever your environment folder is called), run:

```bash
uv sync
```

This is now adding each of the software specified in the flake.nix file into the virtual environment. 

### Managing Python Dependencies

If we want to add a new Python package, we want to add it to the "dependencies" part of the pyproject.toml file:

```python
    dependencies = [
        "ultralytics",
        "fiftyone",
        "label-studio",
        "label-studio-sdk",
        "sh",
        "plotnine"
    ]
```

Go to pypi.org and search the package to make sure you are using the right name. After adding to the pyproject.toml, we have to run:
```bash
uv sync
```

### Managing System Dependencies

If the software is not a Python dependency (ie. awscli), we need to add it to the packages part of the flake.nix file:

```bash
              packages = [
                python_with_pkgs
                python311Packages.venvShellHook
                # We now recommend to use uv for package management inside nix env
                mpkgs.uv
                awscli2

                # Data sharing tools
                # syncthing
                # jq

                # Data inspections tools
                # duckdb
                # mongodb
                arion

                # video tools
                ffmpeg
              ] ++ libList;
```

After adding to flake.nix, we have to run:
```bash
exit

nix develop .
```

To know exactly what name to use, search on https://search.nixos.org/packages.

### Environment Management Commands

To get out of the virtual environment:
```bash
exit
```

To activate a pre-existing environment:
```bash
nix develop .
``` 