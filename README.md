# esxictl

```
 ███████╗███████╗██╗  ██╗██╗ ██████╗████████╗██╗
 ██╔════╝██╔════╝╚██╗██╔╝██║██╔════╝╚══██╔══╝██║
 █████╗  ███████╗ ╚███╔╝ ██║██║        ██║   ██║
 ██╔══╝  ╚════██║ ██╔██╗ ██║██║        ██║   ██║
 ███████╗███████║██╔╝ ██╗██║╚██████╗   ██║   ███████╗
 ╚══════╝╚══════╝╚═╝  ╚═╝╚═╝ ╚═════╝   ╚═╝   ╚══════╝
```

> **Pure bash+curl+fzf CLI tool for standalone Broadcom/VMware ESXi host management.**
> No vCenter. No Python. No Go. No SDKs. Just bash+curl+fzf+core linux utils

---

![License](https://img.shields.io/badge/license-AGPLv3-blue.svg)
![ESXi](https://img.shields.io/badge/ESXi-6.x%20%7C%207.x%20%7C%208.x%20%7C%209.x-brightgreen.svg)
![Shell](https://img.shields.io/badge/shell-bash-orange.svg)
![Version](https://img.shields.io/badge/version-1.0.0-informational.svg)

---

## 📚 Table of Contents

- [Demo](#-demo)
- [Why esxictl?](#-why-esxictl)
- [Features](#-features)
- [Free vs Pro](#-free-vs-pro)
- [Requirements](#-requirements)
- [Tested ESXi Versions](#-tested-esxi-versions)
- [Installation](#-installation)
- [Configuration](#-configuration)
- [Usage](#-usage)
- [Navigation](#navigation)
- [Architecture](#-architecture)
- [QA Compatibility Matrix](#-qa-compatibility-matrix)
- [Disclaimer](#-disclaimer)
- [License](#-license)
- [Acknowledgements](#-acknowledgements)

---

## 📽️ Demo

<!-- Replace with your actual demo GIF/MP4 URL -->
![esxictl demo](assets/esxictl.gif)

---

## 🤔 Why esxictl?

Managing standalone ESXi hosts **without vCenter** has always been painful:

- 🌐 The **ESXi web UI** is limited and clunky
- 💻 **SSH** is raw and requires memorizing commands
- 🐍 Most tools **assume vCenter** is present or require Python/Go runtimes
- 📦 Zero-dependent


**esxictl** fills that gap with a clean, interactive terminal experience — powered entirely by `bash`, `curl` and `fzf`. Zero additional runtime dependencies.

---

## ✨ Features

### 💻 VMs Management
- List, info, power on/off, suspend, resume, reset
- Graceful shutdown and restart (via VMware Tools)
- Snapshot management — list, create, remove, rename, revert
- Register and unregister VMs
- Delete and rename VMs
- Defragment VM disks

### 💽 Datastores Management
- Interactive file browser with create, rename, delete actions
- Refresh and rename datastores
- Mount and unmount VMFS datastores
- Browse NFS datastores

### 🌐 Networks View
- List all virtual switches and port groups
- Inspect network details — VLAN, MTU, NIC teaming, physical uplinks

### 🖥️ Host Management
- Enter and exit maintenance mode
- Shutdown and reboot with previous checking whether in maintenance mode or not

### 🧾 Host Services Management
- List, start, stop, restart, refresh
- Enable, disable, set auto-start, uninstall

### ✨ Smart UX
- Interactive `fzf`-powered menus throughout
- Detailed VM, datastore, host services and networks info preview panels
- Task monitoring with animated braille spinners while being processed
- Colorful actions results
- Multi-select operations on VMs, datastores and services
- Selectable UI themes
- Detailed debug/info/error/warning logging
- Interactive setup wizard
- Built-in help and describe commands

---

## ⚡ Free vs Pro

| Feature | Free | Pro |
|---|:---:|:---:|
| VMs list, info, power ops | ✅ | ✅ |
| VMs snapshots (all ops) | ✅ | ✅ |
| VMs register/unregister/delete/rename | ✅ | ✅ |
| VMs defragment | ✅ | ✅ |
| Datastores browse, info, refresh, rename | ✅ | ✅ |
| Datastores mount/unmount | ✅ | ✅ |
| Networks list and info | ✅ | ✅ |
| Host maintenance, shutdown, reboot | ✅ | ✅ |
| Host services (all 9 ops) | ✅ | ✅ |
| **VMs create** (with ISO attachment) | ❌ | ✅ |
| **VMs clone** | ❌ | ✅ |
| **VMs export/import** (OVA) | ❌ | ✅ |
| **Datastores create** (VMFS + NFS) | ❌ | ✅ |
| **Datastores delete** | ❌ | ✅ |

> 🔗 Interested in the **Pro version**? Coming soon!

---

## 📋 Requirements

| Dependency | Purpose | Install |
|---|---|---|
| `bash` | Shell runtime | Pre-installed on most Linux distros |
| `curl` | HTTPS/SOAP API calls | `apt install curl` / `dnf/yum install curl` / `apk add curl` / `xbps-install -S curl`  |
| `fzf` | Interactive menus | `apt install fzf` / `dnf/yum install fzf` / `apk add fzf` / `xbps-install -S fzf` |
| `xmllint` | XML parsing | `apt install libxml2-utils` / `dnf/yum install libxml2`  / `apk add libxml2-utils` / `xbps-install -S libxml2` |

### 🐧 Tested And Run On Host Operating Systems

| OS | Version | Notes |
|---|---|---|
| Red Hat Linux | 9 Latest (05-2026) | |
| Ubuntu | 24.04.4 (05-2026) | |
| Kali Linux | Latest (05-2026) | |
| Manjaro Linux | Latest (05-2026) | |
| AlmaLinux | 10 Latest (05-2026) | |
| Alpine Linux | 3.23 (05-2026) | | 
| Void Linux | Latest (05-2026) | |

---

## 🖥️ Tested ESXi Versions

| ESXi Version | Status |
|---|:---:|
| 6.7.3 | ✅ |
| 7.0.3 | ✅ |
| 8.0.3 | ✅ |
| 9.0.0 | ✅ |

---

## 🚀 Installation

```bash
# Clone the repository
git clone https://github.com/mytechspacexyz/esxictl.git

# Add esxictl to PATH via symlink in a folder that is already in PATH
# For example:
cd ~/bin; ln -s <esxictl folder>/esxictl esxictl

# Add autocompletion for esxictl in your ~/.bashrc or similar and restart the shell
_esxictl_completion() {
    local cur prev commands debugopts
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    commands="version describe setup debug themes manage help"
    debugopts="on off"

    case "${prev}" in
        esxictl)
            COMPREPLY=($(compgen -W "${commands}" -- "${cur}"))
            return 0
            ;;
        debug)
            COMPREPLY=($(compgen -W "${debugopts}" -- "${cur}"))
            return 0
            ;;
        *)
            ;;
    esac
}
complete -F _esxictl_completion esxictl

# Run setup
esxictl setup
```

---

## ⚙️ Configuration

```bash
On first run `esxictl setup` will guide you through the configuration interactively.
Configuration is stored under the `conf/` directory inside the esxictl folder.

Pay SPECIAL attention to the CA certificate(s) that has to be included (and will be copied to the conf folder)
while running 'esxictl setup'.
It is best to issue before any setup such a certificate for you ESXi host with its FQDN using your internal/external CA
or create a self-signed one as the esxictl is built with curl secure flags to require the CA certificate for a session.
No IP address will be good for this setup.
Usually, the ESXi certificates are under the /etc/vmware/ssl/ folder on an ESXI host

For example:

esxictl setup

Enter ESXi server hostname with port (if non-standard) (esxi10.int.clusteresx.xyz): esxi08.int.alpi.xyz
Enter a ESXi admin username : esxi8man
Enter an ESXi admin password: <password not displayed here>
Enter the full path to CA certificate (ESXi server(s) certificate(s) signed with): /tmp/esxi08.int.alpi.xyz-ca.crt 
setup has been completed successfully.
```

---

## 🎮 Usage

```bash
# Set the esxictl up before its usage
esxictl setup

# Start interactive management
esxictl manage

Note: while managing vms pay attention that some vms actions like shutdown/restart
need the vmware tools to be installed in the vms to be available

# Select fzf UI theme
esxictl themes

# Show description
esxictl describe

# Show help
esxictl help

# Debug mode on
esxictl debug on

# Debug mode off
esxictl debug off

# Show version
esxictl version

# Logs
logs are in the folder logs
written to the file esxictl.log
Can be viewed: tail -f <path to the esxictl main folder>/logs/esxictl.log
```

### Navigation

| Key | Action |
|---|---|
| `↑` / `↓` | Navigate menu |
| `Enter` | Select |
| `Tab` | Multi-select |
| `Ctrl-A` | Select all |
| `Ctrl-D` | Deselect all |
| `Ctrl-P` | Toggle preview panel |
| `Ctrl-H` | Toggle preview panel on actions help |
| `Ctrl-B` | Cancel / go back |
| `Esc` | Exit |

---

## 🏗️ Architecture

```
esxictl (main entry)
├── assets/                         (various assets like media files)
├── conf/                           (configuration files — generated during setup)
│   ├── .common_configvar
│   ├── .configvars
│   ├── .deps
│   └── <CA cert file>
├── data/                           (app's data like session cookie and similar)
│   ├── sessions                    (active sessions files) 
├── docs/                           (documentation files)
│   ├── .help
│   ├── .description
│   └── .version
├── examples/                       (configuration examples)
├── logs/                           (app's logs)
├── src/                            (source code)
│   ├── .functions.bash
│   ├── .functions_init.bash
│   ├── .functions_log.bash
│   ├── .functions_handlers.bash
│   ├── .functions_vms_handlers.bash
│   ├── .functions_datastores_handlers.bash
│   ├── .functions_host_handlers.bash
│   ├── .functions_networking_handlers.bash
│   └── .functions_tasks_handlers.bash
└── tmp/                            (app's temporary files folder)
```

**Design philosophy:** Pure bash+curl+fzf — every function is self-contained with all SOAP XML inline. No shared helpers, no external SDKs. Any function can be extracted and used independently with the main esxictl vars set (see Configuration section above).

---

## 🧪 QA Compatibility Matrix

| Feature | 6.7.3 | 7.0.3 | 8.0.3 | 9.0.0 |
|---|:---:|:---:|:---:|:---:|
| vms list | ✅ | ✅ | ✅ | ✅ |
| vms power ops (linux+windows) | ✅ | ✅ | ✅ | ✅ |
| vms snapshot all ops | ✅ | ✅ | ✅ | ✅ |
| vms register/unregister | ✅ | ✅ | ✅ | ✅ |
| vms delete | ✅ | ✅ | ✅ | ✅ |
| vms rename | ✅ | ✅ | ✅ | ✅ |
| host maintenance enter/exit | ✅ | ✅ | ✅ | ✅ |
| host shutdown/reboot | ✅ | ✅ | ✅ | ✅ |
| host services (all 9 ops) | ✅ | ✅ | ✅ | ✅ |
| datastores browse | ✅ | ✅ | ✅ | ✅ |
| datastores refresh/rename | ✅ | ✅ | ✅ | ✅ |
| datastores mount/unmount | ✅ | ✅ | ✅ | ✅ |
| networks list/info | ✅ | ✅ | ✅ | ✅ |

---

## ⚠️ Disclaimer

esxictl is provided **as-is** without any warranty of any kind, express or implied. The authors and contributors are not responsible for any data loss, system outages, VM deletion, datastore corruption, host unavailability, or any other damages resulting from the use or misuse of this tool.

**Always test in a non-production environment first. Use at your own risk.**

This project is **not affiliated with, endorsed by, or sponsored by Broadcom Inc. or VMware**. All product names, trademarks and registered trademarks are property of their respective owners.

---

## 📄 License

This project is licensed under the **GNU Affero General Public License v3.0 (AGPLv3)** — see the [LICENSE](LICENSE) file for full details.

⚠️  Use of this codebase for AI/ML training is explicitly prohibited — see [AI_USAGE_POLICY.md](AI_USAGE_POLICY.md).

In summary: you are free to use, modify and distribute this software, but any modified version must also be released under AGPLv3 and its source code made available. This applies even when the software is provided as a service over a network.

---

## 🙏 Acknowledgements

- [fzf](https://github.com/junegunn/fzf) — the fuzzy finder that powers the entire UX
- The vSphere SOAP API that makes it all possible:
  - [VMware vSphere Web Services API 9.0](https://developer.broadcom.com/xapis/vsphere-web-services-api/9.0/index.html)
  - [VMware vSphere Web Services API 8.0](https://developer.broadcom.com/xapis/vsphere-web-services-api/8.0U3/index.html)
  - [VMware vSphere Web Services API 7.0](https://developer.broadcom.com/xapis/vsphere-web-services-api/7.0U3/index.html)
- The homelab, MSP and devops/sysadmin community for the inspiration

---

<div align="center">

**Built with ❤️  for MSPs, devops, sysadmins and homelabbers who live in the terminal**

[![GitHub stars](https://img.shields.io/github/stars/mytechspacexyz/esxictl?style=social)](https://github.com/mytechspacexyz/esxictl)

</div>
