# Secrets Management Guide (SOPS + AGE)

This project uses **Mozilla SOPS** and **AGE** to securely store Talos cluster secrets in Git. 

## 1. Setup

### Install Tooling
If not already installed, install `sops` and `age`:
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install age
# Download SOPS from https://github.com/getsops/sops/releases
```

### Generate AGE Key
Generate your personal encryption key:
```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
```

Extract your **public key**:
```bash
age-keygen -y ~/.config/sops/age/keys.txt
```

## 2. Configuration

Update the [.sops.yaml](file:///home/oz/devsecops/talos-gitops-like/.sops.yaml) file in the project root with your public key:

```yaml
creation_rules:
  - path_regex: secrets/.*\.yaml$
    age: "age1..." # <--- REPLACE WITH YOUR PUBLIC KEY
```

## 3. Workflow

### Initialize Secrets (First Time)
```bash
talosctl gen secrets -o ./secrets/secrets.yaml
```

### Encrypt Secrets
```bash
sops -e -i ./secrets/secrets.yaml
```

### Update Secrets
To edit the encrypted secrets file:
```bash
sops ./secrets/secrets.yaml
```

## 4. Automation

The `render.sh` script is designed to detect SOPS-encrypted files. If it finds a `sops:` key in `secrets/secrets.yaml`, it will automatically decrypt it to a temporary location during the rendering process, ensuring your plain-text secrets never touch the disk permanently.
