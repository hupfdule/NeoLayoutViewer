NeoLayoutViewer - Patched
========================================================================

This a patched version of https://github.com/YggdrasiI/NeoLayoutViewer. It
incoporates the Pull Request
https://github.com/YggdrasiI/NeoLayoutViewer/pull/8 and provides the
corresponding release assets under
https://github.com/hupfdule/NeoLayoutViewer/releases.

This repository is not meant as a long-living fork, but only to provide the
binary assets until the above mentioned Pull Request is integrated
upstream.


Beschreibung
========================================================================

Der NeoLayoutViewer bietet eine einfache Möglichkeit, das NEO2-
Tastaturlayout¹ auf dem Bildschirm anzuzeigen. 

Das Programmfenster besteht nur aus dem Bild einer der sechs Ebenen des Layouts.
Wird eine der Mod-Tasten (Shift,…) gedrückt oder losgelassen, wechselt die Anzeige zur zugehörigen
Ebene. Außerdem kann das Fenster per Tastenkombination bewegt oder ausgeblendet werden. 
Alle Einstellungen können über eine Konfigurationsdatei angepasst werden.

Autoren: Olaf Schulz 2011-2018, rixx 2013

Lizenz: GNU Lesser General Public License version 3 (LGPLv3)



Kompilation & Installation
========================================================================

Das Programm benötigt einen Kompiler der Programmiersprache Vala (mind. Version 0.24)
und die Developer-Pakete einiger Bibliotheken. Die Abhängigkeiten können unter Ubuntu
mit dem folgenden Befehl nachinstalliert werden, sofern sie nicht bereits vorhanden sind
(Stand: Ubuntu 16.04, November 2017). Bei anderen Distributionen muss der Befehl ggf. angepasst werden.

    sudo apt-get install valac libgee-0.8-dev libgtk-3-dev libx11-dev libunique-3.0-dev libappindicator3-dev

Mittels

    make; sudo make install

kann das Programm kompiliert und unter /usr/local installiert werden.
Unter Gnome 2.x wird eine andere Bibliothek für die Anzeige des Tray-Icons benötigt.
Geben Sie in diesem Falle „ICON=tray make“ ein.


Hinweise
========================================================================
• Beim ersten Start wird die Datei $HOME/.config/neo_layout_viewer.conf
	erstellt. (Sollte die Datei in diesem Verzeichnis nicht angelegt werden können,
	wird als Speicherort $HOME und das derzeitge Verzeichnis ausprobiert.)
	In der Konfigurationsdatei können unter anderem folgende Einstellungen vorgenommen
	werden:
	- Breite des Fensters. Mit „width“ können Sie die exakte Breite einstellen und mit
		„max_width“ und „min_width“ die relative Breite in Bezug auf die derzeitige Auflösung.
	- Anzeige des Numblocks und der Funktionstasten.
	- Tastenkürzel für Anzeige und Bewegung des Fensters. Möchten Sie die Tasten-
		kombination nicht nutzen, löschen Sie den Text hinter dem Gleichheitszeichen.
		In den Standardeinstellungen kann das Programmfenster mittels Strg+Alt+N an
		acht verschiedene Positionen verschoben werden. Soll nur eine Teilmenge dieser
		Positionen genutzt werden, kann „position_cycle“ angepasst werden.
		Der Wert X∈{1,…,9} ist entsprechend der Position auf dem Numblocks zu interpretieren.
		Beim Druck der Tastenkombination springt das Fenster von Position X zu position_cycle[X].

• Das Programm kann auch als virtuelle Tastatur genutzt werden. Damit die Eingabe das
  richtige Fenster erreicht muss in der Konfigurationsdatei „window_selectable = 0“
  eingetragen werden.

• Das Programm zeigt unter Gnome 3.x in der Indicator-Leiste ein Symbol an. Unter Gnome 2.x
	war für diese Funktion noch eine andere Bibliothek verantwortlich. Sie können im
	Makefile zwischen den beiden Varianten wechseln, indem Sie die Variable ICON anpassen.



______________________________________________________________________
¹NEO ist eine Tastaturbelegung, welche für die deutsche Sprache optimiert ist.

 Die offizielle Seite des Projektes: http://neo-layout.org/
