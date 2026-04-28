# UniFi firewall state — 2026-04-15

> **SUPERSEDED / STALE:** live UniFi now has 8 custom DNS-related policies. Current source-of-truth: [inventory/unifi-firewall.md](../inventory/unifi-firewall.md). This file is historical context only.

## Sammanfattning
Efter senaste UniFi-städningen återstår exakt tre custom policies i controllern.
`IoT DNS to Pi` är enabled och host-scopad till Pi på `192.168.1.55` och `fd12:3456:7801::55`, port `53`.
`block-iot-to-wan-dns-bypass` är enabled och blockerar IoT-zon mot WAN-zon på port `53`.
`Allow MLO → LAN` finns kvar men är disabled eftersom den är verifierat redundant.
Fyra legacy policies är borttagna och materialiseras inte längre i kernel.
Två orphan firewall objects från ett tidigare API-spår är också bortstädade.
Kernelbilden är nu konsekvent med controllerläget: explicit DNS-allow till Pi, explicit WAN:53-block för IoT och fortsatt predefined intra-zone allow för LAN.

## Kvarvarande custom policies

### `IoT DNS to Pi`
- status: enabled
- syfte: tillåta IoT-zonen att resolva DNS endast till Pi
- faktisk scope:
  - destination host = `192.168.1.55`, `fd12:3456:7801::55`
  - destination port = `53`
- enforcement:
  - host-set + port-set i `UBIOS_CUSTOM1_LAN_USER`

### `block-iot-to-wan-dns-bypass`
- status: enabled
- syfte: blockera klassisk DNS-bypass från IoT-zonen till externa resolvers på port `53`
- faktisk scope:
  - src = IoT-zon
  - dst = WAN-zon
  - port = `53`
- enforcement:
  - blockerar före predefined IoT→WAN allow i `UBIOS_CUSTOM1_WAN_USER`

### `Allow MLO → LAN`
- status: disabled
- skäl: verifierat redundant mot predefined intra-zone allow
- MLO-klienttest bekräftade att trafiken fungerar utan regeln

## Bortstädade legacy policies
- `Block IoT → LAN`
- `Block IoT → MLO`
- `Block MLO → IoT`
- `allow-iphone-wiz-control`

Kort varför:
- felzonade
- obsolete
- ej materialiserade i kernel
- gav falsk policykänsla

## Bortstädade orphan objects
- `addr-pi-dns`
- `addr-pi-dns-v6`

Kort notering:
- skapades under misslyckat försök att host-scope:a policy via API
- senare rensade
- inga aktiva beroenden kvar

## Verifierad enforcement-bild
- `IoT DNS to Pi` ligger i `UBIOS_CUSTOM1_LAN_USER`
- använder destination host-set + port-set
- `block-iot-to-wan-dns-bypass` ligger i `UBIOS_CUSTOM1_WAN_USER`
- matchar port `53`
- utvärderas före predefined WAN allow
- LAN intra-zone allow bär fortsatt MLO→Default utan separat customregel

## DNS source-of-truth
- AdGuard = forward authority för `home.lan`
- Unbound = PTR authority
- detta är medvetet nuläge
- IoT DHCP annonserar endast Pi som DNS

## Viktig implementation note
Vid create av zone-policy mot WAN vägrade controllern först requesten med fel kopplat till respond traffic policy.
Fungerande create krävde explicit:
- `create_allow_respond: false`

Detta är viktigt för framtida V2 zone-policy create mot WAN.

## Kvarvarande lågprio-saker
- observera IoT-enheter 24–48h efter WAN:53-block
- avgör senare om disabled `Allow MLO → LAN` ska raderas helt
- dokumentera eventuellt i runbook att MLO-LAN delar zon med Default
- städa Unbound backup-/OFF-filer senare om det inte redan är gjort
