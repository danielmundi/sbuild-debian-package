# Sbuild Debian Package

(Cross-)Build a Debian package using sbuild

This tools assumes you have all required debianization files correct and inplace - this includes control, rules, changelog, etc.

## Inputs
```yaml
inputs:
  distro:
    description: Which Debian distribution to use
    required: false
    default: buster
  arch:
    description: Host architecture to build the package
    required: false
    default: amd64
```