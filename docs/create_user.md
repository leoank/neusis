# Creating Your User Configuration

Copy the example user directory structure from `homes/shsingh` to get started:

```
shsingh/
├── home.nix
├── id_ed25519.pub
└── machines/
    ├── oppy.nix
    └── spirit.nix
```

## Steps

1. Create your directory: `homes/<your-username>`

2. Replace the SSH public key in `id_ed25519.pub` with your own public key (which is in your `~/.ssh/id_ed25519.pub`)

3. Configure `home.nix`:
```nix
home = {
  username = "<your-username>";
  homeDirectory = "/home/<your-username>";
  # ... existing code ...
};
```

4. Set your Git information in `machines/*.nix`:
```nix
(import ../../common/dev/git.nix {
  username = "Your Full Name";
  userEmail = "your.email@example.com";
  id_ed25519_pub = builtins.readFile ../id_ed25519.pub;
})
```
