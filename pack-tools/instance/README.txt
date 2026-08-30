Drop folder for the exported Prism instance zip (order-of-operations step 7).

The cards site serves the NEWEST *.zip in this folder as the download button on
https://cards.archidicks.com/guides/mc-setup  (auth-gated, deeplink-only; the
page itself renders ..\PLAYER-SETUP.md live — edit that file, page updates).

- No zip here = the page shows no download button (still works).
- Publishing an update = drop the new zip; newest mtime wins. Old ones are
  ignored, prune by hand whenever.
- Route code: "C:\Personal Projects\Magic Cards\scripts\app\server.py" (GUIDES).
