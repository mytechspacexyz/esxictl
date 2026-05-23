# Changelog

All notable changes to **esxictl** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2026-05-23

### Added

#### VMs Management
- `vms list` — interactive fzf-powered VM list with info preview panel
- `vms info` — detailed VM information view
- `vms poweron` — power on VMs (multi-select)
- `vms poweroff` — power off VMs (multi-select)
- `vms suspend` — suspend VMs (multi-select)
- `vms resume` — resume suspended VMs (multi-select)
- `vms reset` — reset VMs (multi-select)
- `vms shutdown` — graceful shutdown via VMware Tools (multi-select)
- `vms restart` — graceful restart via VMware Tools (multi-select)
- `vms snapshot list` — list VM snapshots
- `vms snapshot create` — create VM snapshots
- `vms snapshot remove` — remove VM snapshots
- `vms snapshot rename` — rename VM snapshots
- `vms snapshot revert` — revert VM to snapshot
- `vms register` — register VM from datastore browser
- `vms unregister` — unregister VM from inventory
- `vms delete` — delete VM and all its files (multi-select)
- `vms rename` — rename VM display name (multi-select)
- `vms defragment` — defragment VM disks (multi-select)

#### Datastores Management
- `datastores browse` — interactive file browser with create folder, rename, delete actions
- `datastores info` — detailed datastore information view
- `datastores refresh` — refresh datastore storage info (multi-select)
- `datastores rename` — rename datastores (multi-select)
- `datastores mount` — mount VMFS datastores (multi-select)
- `datastores unmount` — unmount VMFS datastores with VM check (multi-select)

#### Networks Management
- `networks list` — list all virtual switches and port groups with info preview panel
- `networks info` — detailed network info — VLAN, MTU, NIC teaming, physical uplinks, link speed

#### Host Management
- `host maintenance enter` — enter host maintenance mode
- `host maintenance exit` — exit host maintenance mode
- `host shutdown` — shutdown ESXi host with maintenance mode check
- `host reboot` — reboot ESXi host with maintenance mode check

#### Host Services Management
- `host services list` — list all host services with info preview panel
- `host services start` — start host service (multi-select)
- `host services stop` — stop host service (multi-select)
- `host services restart` — restart host service (multi-select)
- `host services refresh` — refresh host service (multi-select)
- `host services enable` — enable host service (multi-select)
- `host services disable` — disable host service (multi-select)
- `host services auto` — set host service to auto-start (multi-select)
- `host services uninstall` — uninstall host service (multi-select)

#### Core Features
- Interactive `fzf`-powered menus throughout with detailed preview panels
- Task monitoring with animated braille spinners
- Colorful action results with ✔/✗ indicators
- Session keepalive — automatic background ping every 10 minutes to prevent session expiry
- Selectable fzf UI themes via `esxictl themes`
- Detailed debug/info/error/warning logging via `esxictl debug on/off`
- Interactive setup wizard via `esxictl setup`
- Built-in help via `esxictl help`
- Built-in description via `esxictl describe`
- Bash autocompletion support
- Auto-fix for vCloud Director OVAs on import (VirtualSystemCollection unwrapping)

#### Compatibility
- Tested on ESXi **6.7.3**, **7.0.3**, **8.0.3**, **9.0.0**
- Tested on host OS: Ubuntu 24.04, RHEL 9, Kali Linux, Manjaro, AlmaLinux 10, Alpine 3.23, Void Linux
- Tested VM guests: Linux (Alpine, Debian, Rocky, AlmaLinux, Ubuntu, Void) and Windows 10

---

## Links

- [esxictl on GitHub](https://github.com/mytechspacexyz/esxictl)
- [Report a bug](https://github.com/mytechspacexyz/esxictl/issues)
- [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
- [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
