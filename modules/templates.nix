# Flake templates (`nix flake init -t github:leoank/neusis#<name>`).
# The template sources live at the repo root in `templates/`; the index
# there is a plain attrset of { path; description; }.
{ ... }:
{
  flake.templates = import ../templates;
}
