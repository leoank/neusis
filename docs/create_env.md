# Creating Environments

`homes/<username>/home.nix` describes the base environment for your user account (e.g. programs available specifically to your user account, dotfiles, etc.)

For a given project, you may want to create a separate project-specific environment with additional tools. For this you can create a new environment (nix shell) that is specific to the project.

## Directly from template

In your home folder run:

`nix flake new -t github:leoank/neusis#pythonml <project_name>`

This will create a new environment using the template in `templates/pythonml`.

`cd` into `<project_name>`

You may edit the `flake.nix` file to include any additional programs you wish. Since the template creates a python project, there is no need to specify any python-specific packages (packages from PyPI) in the `flake.nix`, as those will instead be handled by `uv` and go in `pyproject.toml` instead.

To activate the virtual environment, from within the `<project_name>` directory run: `nix develop .`

"Activating" the virtual environment, in nix parlance, means you are put into a new "nix shell".

You can verify this by running:

```
echo $VIRTUAL_ENV
```

Which will show something like:

```
> /home/<username>/<project_name>/.venv
```

Running `uv sync` will install the python dependencies. The `pyproject.toml` can be edited as you see fit.

## Editing the shell

If you want to edit the shell (not the `uv` environment, but the nix shell), you will need to edit the `flake.nix` file.

This requires a basic understanding of the [nix language](https://nix.dev/manual/nix/2.24/language/index.html).

