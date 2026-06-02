# Trunk Setup

This repo uses [Trunk](https://trunk.io) for security scanning and code quality checks.

## Developer setup

If the Trunk CLI is not already installed on your machine:

```bash
curl https://get.trunk.io -fsSL | bash
```

If Trunk has not been initialised for this repo (i.e. no `.trunk/` hooks are active in your local clone):

```bash
trunk install
```

This activates the pre-commit and pre-push hooks. It only needs to be run once per clone.
