# ProcessPath — OTOBO AgentTicketZoom Widget

**Version:** 0.1.1 (erster Test-Release) · **Zielversion:** OTOBO 11.0.x (ab 11.0.13)

ProcessPath zeigt in der Agenten-Ticketansicht den vollständigen Prozessgraphen mit allen Verzweigungen. Die aktuelle Aktivität ist blau markiert, aus der Tickethistorie belegte Aktivitäten und Übergänge sind grün markiert. Sobald die aktuelle Aktivität kein ausgehendes Übergangsziel mehr hat (Endaktivität), wird das Widget standardmäßig eingeklappt.

## Installation

1. `ProcessPath-0.1.1.opm` über **Admin → Paketverwaltung** installieren.
2. Falls OTOBO es verlangt, SysConfig bereitstellen und Browser-Cache/Loader-Dateien aktualisieren.
3. Ein Prozessticket in `Action=AgentTicketZoom;TicketID=...` öffnen.

Das Widget erscheint im Hauptbereich direkt nach der Aktionsleiste. Bei Tickets ohne Prozess wird es nicht angezeigt. Die OTOBO-Core-Dateien werden nicht verändert; die optische Positionierung erfolgt durch `ProcessPath.js`.

## Verhalten und Einschränkungen

- **Ende-Erkennung:** Die aktuell aktive Aktivität ist eine Endaktivität, wenn sie laut aktueller Prozessdefinition **keine ausgehenden Übergänge** besitzt. Ein geschlossener Ticketstatus alleine reicht nicht aus. Der Prozessdesigner sollte eine eindeutige Endaktivität vorsehen.
- **Historie:** Grüne Haken setzen vorhandene `TicketDynamicFieldUpdate`-Historieneinträge des Prozessaktivitätsfeldes voraus. Ohne solche Einträge werden keine vergangenen Aktivitäten erfunden.
- **Änderungen an der Prozessdefinition:** Alte Aktivitäten/Übergänge, die aus der aktuellen Definition entfernt wurden, können nicht mehr visualisiert werden. Die Statusanzeige basiert auf der aktuellen Definition.
- **Verzweigungen und Schleifen:** Alle Knoten und Kanten des definierten Graphen werden angezeigt; Rücksprünge werden als gebogene Kanten gezeichnet. Die erste Version verwendet ein einfaches Spaltenlayout, keine pixelgenaue Kopie des Prozessdesigners.
- **Aufklappen:** Aktive Prozesse starten ausgeklappt, Endaktivitäten eingeklappt. Die Auswahl des Agenten wird nicht zwischen Seitenaufrufen gespeichert.
- **Ressourcen:** Keine Datenbankänderungen, keine neuen Dynamic Fields, keine externen JavaScript-Bibliotheken.
- **Rechte:** Die AgentTicketZoom-Rechte gelten weiterhin, alle Funktionen sind schreibgeschützt.

## Technische Struktur

- `Kernel/Output/HTML/TicketZoom/ProcessPath.pm`: Widget-Integration, Prozessdaten, Ticket-Historie
- `Kernel/System/ProcessPath/Graph.pm`: Graphlayout, Status-/Historienlogik
- `Kernel/Output/HTML/Templates/Standard/AgentTicketZoom/ProcessPath.tt`: HTML/SVG
- `var/httpd/htdocs/js/ProcessPath.js`: Platzierung unter der Ticket-Aktionsleiste
- `var/httpd/htdocs/skins/Agent/default/css/ProcessPath.css`: ausschließlich lokale Styles
- `Kernel/Config/Files/XML/ProcessPath.xml`: SysConfig + Loader
- `tests/graph.t`: automatische Tests der Prozesspfadlogik

## Tests

```bash
prove -v tests/graph.t
```

Ergänzende Installations- und Abnahmetests siehe `docs/ADMIN.md`.

### Activity titles (0.1.1)

Activity names wrap automatically onto two or more lines. Names are never truncated. Tiles increase in height if the label needs additional lines.
