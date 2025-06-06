# Getting Started with Neusis

This guide documents the process for setting up an account and environment in the Neusis system. It covers SSH key generation, user configuration, and Home Manager setup. Home Manager enables users to customize their environment and test changes without administrator intervention. The guide also explains how to ensure changes persist through system rebuilds. Following these procedures will result in a functional, customized development environment.

## Initial Setup

### Generate SSH Keys

First, you'll need to generate a secure SSH key pair using the ED25519 algorithm:

```bash
ssh-keygen -t ed25519
```

FIXME: Do this on your local machine if on Linux or Mac, or through WSL on Windows.

This will create your SSH key pair that will be used for secure authentication across the system.

### Create Your User Configuration

1. Fork and check out this repository. FIXME: neusis
2. Create your user config directory: `homes/<your-username>`. Copy the example user directory structure from `homes/shsingh` to your new user config directory to get started:
   ```
   <your-username>/
   ├── home.nix         # Core configuration for username, home dir, and packages
   ├── id_ed25519.pub   # Your SSH public key for authentication
   └── machines/
       ├── oppy.nix     # Machine-specific config that imports modules and sets Git info
       └── spirit.nix   # Same as above but for a different machine
   ```
3. Replace the SSH public key in `id_ed25519.pub` with your own public key (which is in your `~/.ssh/id_ed25519.pub`)
4. Configure `home.nix`:
   ```nix
   home = {
     username = "<your-username>";
     homeDirectory = "/home/<your-username>";
     # ... existing code ...
   };
   ```
5. Set your Git information in `machines/*.nix`:
   ```nix
   (import ../../common/dev/git.nix {
     username = "Your Full Name";
     userEmail = "your.email@example.com";
     id_ed25519_pub = builtins.readFile ../id_ed25519.pub;
   })
   ```

### Enable Home Manager Functionality 

Home Manager is a tool that allows you to customize your environment without administrator intervention. Its main advantage is that it lets you test changes immediately without waiting for admin approval.

You will want to customize your home environment in various ways, such as:
- Installing programs, that you want to always have around, and are specific to your user account
- Customizing your shell prompt
- Modifying your `.bashrc` or `.zshrc`
- Setting up development tools and environments

Without Home Manager, the process to make these changes is slow and cumbersome:
1. Make changes to your configuration files
2. Send a PR to the `neusis` repo
3. Wait for admin to merge changes and rebuild (`nixos-rebuild`)
4. Only then can you see if your changes work as expected

With Home Manager, you get an immediate feedback loop:
1. Set up Home Manager access once (requiring an initial PR)
2. Then iteratively modify your `home.nix` and test immediately with `home-manager switch`
3. Submit final changes as PR when you're satisfied

This immediate testing capability is crucial, as going through the admin approval process only to find syntax errors would be frustrating.

To enable Home Manager:

1. Add an entry for yourself in `neusis/flake.nix` under the `homeConfigurations` section:
   ```nix
   "<your-username>@<machine>" = lib.homeManagerConfiguration {
     pkgs = pkgsFor.x86_64-linux;
     extraSpecialArgs = { inherit inputs outputs; };

     modules = [
       inputs.agenix.homeManagerModules.default
       ./homes/<your-username>/machines/<machine>.nix
     ];
   }
   ```
   Replace `<your-username>` with your user name, and `<machine>` with the relevant server (e.g., `oppy` or `spirit`).

2. Submit your changes as a PR with all the configuration created so far.

3. After the admin approves and merges these changes, you'll be able to use Home Manager to customize your environment.

## Using Home Manager to Customize Your Environment

Once your initial PR has been merged, you can begin customizing your environment by modifying `neusis/homes/<your-username>/home.nix`. This file controls your user-specific configuration, including installed packages, shell settings, and more.

### Testing Your Changes

After making changes to your configuration, apply them using Home Manager:

```bash
cd ~/neusis # or wherever the neusis repo lives for you
nix-shell -p home-manager
home-manager switch --flake .#<your-username>@<machine>
exit
```

Note that the `#` symbol above in `.#<your-username>@<machine>` does not denote a comment. It is part of the syntax to the `home-manager switch --flake` command.

Again, make sure to replace `<your-username>` with your actual username and `<machine>` with the machine you're targeting (e.g., `oppy` or `spirit`).

If you have installed new programs, they should now be available (try `which <program_name>`). If you have modified your shell login file (e.g., `.bashrc` or `.zshrc`), you will need to source it (e.g., `source ~/.zshrc`) or logout and log back in to see the changes.

### Submitting Changes

**IMPORTANT:** After you've customized your home environment to your satisfaction using Home Manager, you **must** commit and push these changes to the main repository. This step is critical for several reasons:

1. While `home-manager switch` immediately applies your changes locally, these changes aren't automatically synchronized with the main system configuration.

2. When the admin performs a global system rebuild (`nixos-rebuild`), the system will use the configuration files from the main branch.

3. If you haven't pushed your changes, your home environment will revert to its previous state during the next system rebuild.

To ensure your changes persist:

```bash
# From the neusis repository
git add homes/<your-username>/
git commit -m "Update home configuration for <your-username>"
git push 
```

Then create a pull request so the admin can review and merge your changes into the main branch. This ensures your customizations become part of the system's permanent configuration.

Even though your changes are already active due to running `home-manager switch` locally, completing this PR process is essential for maintaining your preferred configuration long-term. 
