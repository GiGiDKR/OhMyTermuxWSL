# OhMyTermuxWSL

![Logo of OhMyTermuxWSL]

A [Docker](https://www.docker.com/) installation script in [WSL2](https://learn.microsoft.com/en-us/windows/wsl/about) that runs [Termux ](https://termux.dev/en/).

## Prerequisites

- Install [WSL2](https://learn.microsoft.com/en-us/windows/wsl/about)
- Install Linux distro (ex: Ubuntu) :
```bash
wsl --install
```
Once logged into Ubuntu, paste the code :
```bash
curl -sL https://raw.githubusercontent.com/GiGiDKR/OhMyTermuxWSL/refs/heads/1.0.0/install.sh -o install.sh && chmod +x install.sh && ./install.sh
```

> [!WARNING]
> Preview version (only for internal development) :
> ```bash
> curl -sL https://raw.githubusercontent.com/GiGiDKR/OhMyTermuxWSL/refs/heads/dev/install.sh -o install.sh && chmod +x install.sh && ./install.sh
> ```
