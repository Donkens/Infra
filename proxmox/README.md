# Proxmox workspace

The Opti Proxmox host is a hypervisor only. It should not run application workloads directly.

| Host | IP | Role |
| --- | --- | --- |
| `opti.home.lan` | `192.168.1.60` | Proxmox host |
| `proxmox.home.lan` | `192.168.1.60` | Proxmox UI/API alias |

Boundaries:

- UDR-7 owns gateway, VLAN, firewall, and WireGuard.
- Pi owns DNS.
- VM `101` owns HAOS.
- VM `102` owns Docker services.
- No long-lived snapshots.
