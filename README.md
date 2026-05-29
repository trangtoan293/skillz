# skillz — Personal Claude Code Marketplace

A Claude Code plugin marketplace by [@trangtoan293](https://github.com/trangtoan293).

## Install

In any Claude Code session:

```
/plugin marketplace add trangtoan293/skillz
/plugin install claude-dev-toolkit@skillz
```

## Available plugins

### claude-dev-toolkit

End-to-end development workflow: research codebase → plan → execute (sequential or parallel) with multi-plan support and hand-off enforcement.

See [`plugins/claude-dev-toolkit/README.md`](./plugins/claude-dev-toolkit/README.md) for full documentation.

## Repository structure

```
skillz/
├── .claude-plugin/
│   └── marketplace.json           ← marketplace catalog
└── plugins/
    └── claude-dev-toolkit/
        ├── .claude-plugin/plugin.json
        ├── bin/
        ├── hooks/
        ├── skills/
        └── README.md
```
