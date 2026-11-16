# ProcessPath — OTOBO AgentTicketZoom Widget

**Version:** 0.1.4 (erster Test-Release) · **Zielversion:** OTOBO 11.0.x (ab 11.0.13)

ProcessPath zeigt in der Agenten-Ticketansicht den aktuellen Prozessschritt und alle von dort aus noch möglichen, nicht bereits abgeschlossenen Prozesszweige. Der aktuelle Schritt ist blau. Erledigte Schritte stehen als schmale, um 90° gedrehte **Textkacheln am linken Rand** (ohne Symbol oder Statusuntertitel). Verlassene, nicht durchlaufene Zweige werden ausgeblendet. Sobald die aktuelle Aktivität kein ausgehendes Übergangsziel mehr hat (Endaktivität), wird das Widget standardmäßig eingeklappt.

## Installation

1. `ProcessPath-0.1.3.opm` über **Admin → Paketverwaltung** installieren.
2. Falls OTOBO es verlangt, SysConfig bereitstellen und Browser-Cache/Loader-Dateien aktualisieren.
3. Ein Prozessticket in `Action=AgentTicketZoom;TicketID=...` öffnen.

Das Widget erscheint im Hauptbereich direkt nach der Aktionsleiste. Bei Tickets ohne Prozess wird es nicht angezeigt. Die OTOBO-Core-Dateien werden nicht verändert; die optische Positionierung erfolgt durch `ProcessPath.js`.


## Prozesse gezielt freigeben (ab 0.1.4)

Unter **Admin → Systemkonfiguration** nach `ProcessPath::VisibleProcesses` suchen.
Dies ist eine bearbeitbare Liste: Jeder neue Eintrag bietet eine Auswahlliste mit
allen konfigurierten Prozessen, dargestellt als **Prozessname [ProcessEntityID]**.
Auch inaktive und ausgeblendete Prozesse können für bestehende Tickets ausgewählt werden.

- **Voreinstellung:** `All processes (*)` — zur Wahrung des bisherigen Verhaltens bleibt die Anzeige für alle Prozesse aktiv.
- **Nur bestimmte Prozesse:** `All processes (*)` entfernen und jeweils den gewünschten Prozess hinzufügen.
- **Keine Prozesse:** Alle Einträge löschen.
- **Nach Änderungen:** Einstellung speichern und die OTOBO-Systemkonfiguration bereitstellen.

Die Auswahl ist dauerhaft über die stabile `ProcessEntityID` verankert. Wird ein Prozess
umbenannt, bleiben bestehende Freigaben wirksam. Eine nicht freigegebene Prozess-ID
führt zu keiner Anzeige des Widgets (auch nicht bei abgeschlossenen Tickets).

## Verhalten und Einschränkungen

- **Ende-Erkennung:** Die aktuell aktive Aktivität ist eine Endaktivität, wenn sie laut aktueller Prozessdefinition **keine ausgehenden Übergänge** besitzt. Ein geschlossener Ticketstatus alleine reicht nicht aus. Der Prozessdesigner sollte eine eindeutige Endaktivität vorsehen.
- **Historie:** Durchlaufene Schritte werden aus `TicketDynamicFieldUpdate`-Historieneinträgen ermittelt und nur einmal in chronologischer Reihenfolge als grüne, gedrehte Textkacheln dargestellt. Ohne Historie wird nur die aktuelle Aktivität angezeigt.
- **Änderungen an der Prozessdefinition:** Alte Aktivitäten/Übergänge, die aus der aktuellen Definition entfernt wurden, können nicht mehr visualisiert werden. Die Statusanzeige basiert auf der aktuellen Definition.
- **Verzweigungen und Schleifen:** Noch mögliche Zweige ab der aktuellen Aktivität werden angezeigt. Bereits verlassene, nicht durchlaufene Zweige verschwinden. Bei Rücksprüngen werden erneut erreichbare Möglichkeiten wieder angezeigt. Der Graph durchläuft keine schon erledigten Aktivitäten, um vergangene Alternativen unnötig erneut einzublenden. Die Darstellung ist keine pixelgenaue Kopie des Prozessdesigners.
- **Aufklappen:** Aktive Prozesse starten ausgeklappt, Endaktivitäten eingeklappt. Die Auswahl des Agenten wird nicht zwischen Seitenaufrufen gespeichert.
- **Ressourcen:** Keine Datenbankänderungen, keine neuen Dynamic Fields, keine externen JavaScript-Bibliotheken.
- **Rechte:** Die AgentTicketZoom-Rechte gelten weiterhin, alle Funktionen sind schreibgeschützt.

## Technische Struktur

- `Kernel/Output/HTML/TicketZoom/ProcessPath.pm`: Widget-Integration, Prozessdaten, Ticket-Historie
- `Kernel/System/ProcessPath/Visibility.pm`: Filterung nach erlaubten Prozessen
- `Kernel/System/SysConfig/ValueType/Entity/ProcessPathProcess.pm`: dynamische Prozessauswahl in SysConfig
- `Kernel/System/ProcessPath/Graph.pm`: Graphlayout, Status-/Historienlogik
- `Kernel/Output/HTML/Templates/Standard/AgentTicketZoom/ProcessPath.tt`: HTML/SVG
- `var/httpd/htdocs/js/ProcessPath.js`: Platzierung unter der Ticket-Aktionsleiste
- `var/httpd/htdocs/skins/Agent/default/css/ProcessPath.css`: ausschließlich lokale Styles
- `Kernel/Config/Files/XML/ProcessPath.xml`: SysConfig + Loader
- `tests/graph.t`: automatische Tests der Prozesspfadlogik

## Tests

```bash
prove -v tests/*.t
```

Ergänzende Installations- und Abnahmetests siehe `docs/ADMIN.md`.

### Aktivitätsnamen

Aktuelle und zukünftige Aktivitäten brechen ihre Beschriftung bei Bedarf über mehrere Zeilen um, ohne Kürzungen. Erledigte Aktivitäten erscheinen links in vertikalen Textkacheln ohne Haken oder Untertitel. Erledigte Schritte bleiben ausnahmslos in einer einzigen horizontalen Reihe. Bei Bedarf kann die Leiste separat seitlich gescrollt werden; es gibt keinen Zeilenumbruch. Die Breite des restlichen SVG wurde durch kleinere Abstände reduziert.
