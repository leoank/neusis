# ADR-0005: Modules take their data as options and do nothing until enabled; features are config-only; users and machines opt in

Status: accepted
Date: 2026-06-16
Backfilled: 2026-11-03, from `AGENTS.md` (*Contributing guidelines*), `porting.md`
(2026-06-16 umbrellas and opt-in services, 2026-08-12 *Patterns confirmed*, 2026-08-16
*Module is imported by the machine; features are config-only*).

## Context
neusis is both a library for consumer repos and the config of one person's fleet. Its
modules have to be usable outside that fleet, and nobody should get a service or a tool
just by importing something. Alternatives were not recorded.

## Decision
- **Reusable modules** (`agnosticModules/`, `nixosModules/`, `darwinModules/`,
  `homeModules/`) declare options and do nothing until enabled. They take the data they
  need as options (`build-client` takes `builders` as a list instead of reading
  `self.neusis.registry`).
- **Home umbrellas** (`supercharged-git`, `supercharged-shell`, `terminal-velocity`,
  `agent-harness`) import their tool sub-modules, and each tool has its own
  `tools.<x>.enable`. Long-running services are opt-in as well.
- **Features** (`features/`) are config-only opinionated wiring: values and secrets for
  the modules, never option declarations.
- **Machines** import modules and features. **Users** choose home bundles in
  `modules/users/<user>/`; shells, editors, SSH agents and other personal tools live
  only there.

## Consequences
- Importing a module or umbrella changes nothing until something is enabled. The tests
  pin this ("everything off by default").
- Consumers can reuse a module with their own data, for example a builder list outside
  anklab.
- Shared defaults never switch anything on, so a new tool needs an explicit enable in a
  user bundle or a machine file.
