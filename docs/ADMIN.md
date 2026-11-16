# ProcessPath — Administratorhandbuch

## Voraussetzungen

- OTOBO 11.0.13 bzw. 11.0.x
- Prozessmanagement eingerichtet
- Agentenrechte zum Öffnen des Tickets

## Installation

1. In OTOBO als Administrator anmelden.
2. **Admin → Paketverwaltung** öffnen.
3. Paket `ProcessPath-0.1.3.opm` hochladen und installieren.
4. Gegebenenfalls **Systemkonfiguration** bereitstellen / Loader-Cache regenerieren.
5. Ein Prozessticket öffnen: `/otobo/index.pl?Action=AgentTicketZoom;TicketID=...`.

Die beiden SysConfig-Einträge `Ticket::Frontend::AgentTicketZoom###Widgets###0050-ProcessPath` und `Loader::Module::AgentTicketZoom###050-ProcessPath` müssen aktiviert sein.

## Testfälle

1. Normales Ticket: Widget fehlt.
2. Prozessticket in Anfangsaktivität: Widget sichtbar und ausgeklappt; Start blau.
3. Fortschritt über mehrere Übergänge: Vergangene Aktivitäten als schmale, gedrehte Textkacheln links (ohne Haken); aktuelle blau.
4. Prozess mit Genehmigung/Ablehnung: Vor der Entscheidung beide Zweige sichtbar; nach der Entscheidung wird der nicht gewählte, nicht mehr erreichbare Zweig ausgeblendet.
5. Rücksprung in eine frühere Aktivität: Erledigte Aktivitäten werden nicht dupliziert; aktueller Knoten bleibt blau, ab dort wieder verfügbare Zweige werden eingeblendet.
6. Aktivität ohne ausgehende Übergänge: Widget startet eingeklappt. Klick auf Überschrift öffnet Graph.
7. Ticketstatus geschlossen, aber Aktivität hat noch Übergänge: Widget bleibt ausgeklappt.
8. Prozessticket erneut öffnen: Ein-/Ausklappstatus richtet sich erneut nach aktueller Aktivität.
9. Mobile Ansicht: Graph ist horizontal scrollbar und bedienbar.
10. Deinstallation: Widget und Loader-Einträge sind entfernt.

## Diagnose

- Widget fehlt: Prozess-ID und Aktivitäts-ID im Ticket prüfen, Prozessdefinition und Paketeinstellungen kontrollieren.
- Widget erscheint weiter unten: Browsercache und JS Loader-Eintrag kontrollieren; ohne das kleine Positionierungsskript bleibt es an der regulären OTOBO-Position für `MainWidgets`.
- Keine gedrehten Textkacheln: In der Tickethistorie auf `TicketDynamicFieldUpdate` des konfigurierten Aktivitätsfeldes prüfen. Ohne Historie wird nur der aktuelle Schritt angezeigt.
- Falscher Abschlusszustand: Endaktivität im Prozessdesigner auf ausgehende Übergänge kontrollieren. `closed` als Ticketstatus ist nicht das Abbruchsignal für das Diagramm.

## Bekannte Grenzen der Testversion

- Auswertung der vollständigen Tickethistorie beim Aufruf des Widgets (historisch sehr umfangreiche Tickets können zusätzliche Ladezeit verursachen).
- Der Graph verwendet eine eigene automatische Positionierung und entspricht nicht dem Designerlayout. Frühere, nicht mehr erreichbare Alternativen werden nicht angezeigt.
- Alte Historienereignisse können bei manuell oder durch andere Module modifizierten Dynamic Fields fehlen.
- OTOBO-Liveintegration und Browserdarstellung müssen in einer Testinstanz abgenommen werden.

### Lange Aktivitaetsnamen

Namen aktiver und künftiger Aktivitäten werden vollständig und mehrzeilig dargestellt. Erledigte Aktivitäten stehen kompakt links als um 90° gedrehte, reine Textkacheln (ohne Icons).
