Überblick

DRKalenderPopup ist ein leichtgewichtiges World of Warcraft Addon, das Spieler beim Login automatisch über offene Gildenereignisse im Kalender informiert.

Sobald ein Ereignis im Gildenkalender existiert, auf das noch nicht reagiert wurde, erscheint beim Einloggen ein visuelles Popup-Fenster mit Eventdetails.

Das Addon wurde speziell für die Gilde Darkness Rising entwickelt, kann jedoch leicht für andere Gilden angepasst werden.

Features
Login-Benachrichtigung

Beim Login prüft das Addon automatisch:

ob Gildenereignisse existieren

ob ein Ereignis für das Addon noch offen ist

Wenn ein Ereignis gefunden wird, erscheint ein Popup mit den Eventinformationen.

Eventinformationen im Popup

Das Popup zeigt:

Gildenname

Gildenlogo

Eventname

Eventdatum

Hinweistext

Buttons zur Interaktion

Interaktionsmöglichkeiten

OK

öffnet direkt den WoW-Kalender

markiert das Ereignis als bearbeitet

Später

schließt das Popup nur für die aktuelle Spielsitzung

beim nächsten Login erscheint die Erinnerung erneut

Responsives Layout

Das Popup ist so gestaltet, dass es automatisch funktioniert mit:

unterschiedlichen Bildschirmauflösungen

UI-Skalierung

verschiedenen Schriftgrößen

verschiedenen Systemen

Dadurch wird verhindert, dass sich UI-Elemente überlappen.

Chatbefehle

Das Addon enthält einige Debug- und Testbefehle.

Test-Popup anzeigen
/drpopup test

Zeigt das Popup sofort an.

Kalender manuell prüfen
/drpopup scan

Startet eine manuelle Suche nach offenen Gildenereignissen.

Ereignisse erneut als offen markieren
/drpopup reset

Markiert bekannte Ereignisse wieder als offen.

Gespeicherte Daten löschen
/drpopup clear

Löscht alle gespeicherten Ereignisse.

Installation

Repository herunterladen oder klonen

Ordner DRKalenderPopup kopieren nach

World of Warcraft/_retail_/Interface/AddOns/

Spiel starten oder /reload ausführen

Ordnerstruktur
DRKalenderPopup
│
├── DRKalenderPopup.toc
├── DRKalenderPopup.lua
├── logo.tga
├── icon.tga
└── README.md
Technische Details

Das Addon nutzt die Blizzard API:

C_Calendar.GetNumGuildEvents()
C_Calendar.GetGuildEventInfo()

um Gildenereignisse auszulesen und deren Status zu prüfen.

Die Prüfung erfolgt ausschließlich beim Login, um unnötige Event-Listener während des Spielens zu vermeiden.

Anpassung

Wenn das Addon für eine andere Gilde verwendet werden soll, kann der Gildenname einfach geändert werden:

local GUILD_NAME = "Darkness Rising"
Lizenz

Dieses Projekt wurde für die Gilde Darkness Rising erstellt.
Der Code kann frei angepasst oder erweitert werden.
