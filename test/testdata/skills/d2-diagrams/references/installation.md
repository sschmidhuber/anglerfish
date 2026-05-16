# D2 Installation Guide

## Linux & macOS (official install script)

```bash
curl -fsSL https://d2lang.com/install.sh | sh
```

This installs the `d2` binary to `/usr/local/bin` by default.

## macOS (Homebrew)

```bash
brew install d2
```

## Windows (Scoop)

```powershell
scoop install d2
```

## Windows (Winget)

```powershell
winget install terrastruct.d2
```

## From GitHub Releases

Download the latest binary from:
https://github.com/terrastruct/d2/releases

```bash
# Example for Linux amd64
curl -L https://github.com/terrastruct/d2/releases/latest/download/d2-linux-amd64.tar.gz \
  | tar -xz
sudo mv d2 /usr/local/bin/d2
```

## Verify Installation

```bash
d2 --version
```

## Optional: TALA Layout Engine

TALA is a premium layout engine that produces more organic, aesthetically pleasing layouts for complex graphs. It requires a license from Terrastruct.

```bash
# Install TALA plugin (requires license key)
curl -fsSL https://d2lang.com/install-tala.sh | sh
export TALA_TOKEN=your-license-key
d2 --layout tala diagram.d2 out.svg
```

## VS Code Extension

Install the **D2** extension for syntax highlighting and live preview:

```
ext install terrastruct.d2
```

Or search for "D2" in the VS Code Extensions marketplace.

## CI / Docker

```dockerfile
FROM debian:bookworm-slim
RUN curl -fsSL https://d2lang.com/install.sh | sh
```

Or use the official image:
```bash
docker run --rm -v "$PWD":/work terrastruct/d2 d2 /work/diagram.d2 /work/out.svg
```
