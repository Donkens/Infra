# UniFi firewall state — 2026-04-14

## Sammanfattning
UniFi har nu två kvarvarande custom policies.
`IoT DNS to Pi` är aktiv och host-scopad till Pi DNS på `192.168.1.55` och `fd12:3456:7801::55`, port `53`.
`Allow MLO → LAN` finns kvar men är disabled efter verifiering att den är redundant mot predefined intra-zone allow.
Fyra legacy-regler och två orphan firewall groups har städats bort.
Den aktiva enforcement-bilden är nu mindre och tydligare utan att ändra faktisk policyfunktion.

## Kvarvarande custom policies
- `IoT DNS to Pi`
  - status: enabled
  - syfte: tillåta IoT-zonen att resolva DNS endast till Pi
  - faktisk scope: host-scopad till `192.168.1.55` och `fd12:3456:7801::55`, port `53`
- `Allow MLO → LAN`
  - status: disabled
  - skäl: verifierat redundant mot predefined intra-zone allow

## Bortstädade legacy policies
- `Block IoT → LAN`
- `Block IoT → MLO`
- `Block MLO → IoT`
- `allow-iphone-wiz-control`

Skäl: felzonade, obsolete, ej materialiserade i kernel och gav falsk policykänsla utan live-effekt.

## Bortstädade orphan objects
- `addr-pi-dns`
- `addr-pi-dns-v6`

## Verifierad enforcement-bild
- `IoT DNS to Pi` materialiseras i `UBIOS_CUSTOM1_LAN_USER`.
- Enforcement använder destination host-set och port-set, inte manuella address groups.
- Predefined intra-zone allow bär fortfarande LAN-zon intern trafik via `UBIOS_LAN_LAN_USER`.
- `Allow MLO → LAN` behövs därför inte funktionellt.

## DNS source-of-truth
- AdGuard = forward authority för `home.lan`
- Unbound = PTR authority
- detta är nu medvetet nuläge

## Kvarvarande manuellt test
- verkligt test från iPhone/MLO-klient till host i `Default`
- bara som sista sanity-check, inte för att något redan ser trasigt ut

## Nästa möjliga förbättringar
- överväg `block-iot-to-wan-dns-bypass` efter kontrollerad observation
- dokumentera DNS authority i runbook om det inte redan finns
- städa Unbound backup-/OFF-filer senare
- avgör senare om disabled `Allow MLO → LAN` ska raderas helt
