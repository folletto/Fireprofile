Fireprofile
===========

**Firefox Profiles Launcher using Local/Portable folders. GPL licensed.**  



WHAT IS FIREPROFILE
-------------------

It's just a simple app that allows you to launch a local (separate) copy of Firefox
using one or many local (separate) profile folder.


CONTRIBUTE AND BUILD
--------------------

* Download / Clone this repository
* Run in Xcode
* Right click on the running app icon then `Options` → `Show in Finder`.
* In the folder that opens up:
  * add a copy of `Firefox.app`.
  * add a `/profile` subfolder with some empty folders inside it that will be used as profiles.
* Close the app and re-run it.

In the same way you can build and keep it as a separate standalone App: `Product` → `Archive` → `Export...`.



KNOWN LIMITATIONS
-----------------

* The folder management is manual: create `/profile` and empty folders inside it with the profile names.
* Doesn't include Firefox.


TODO
----

* UI, Icon...


MAY DO
------

* Manage profiles directly (add/rename/delete)
* Download latest version of Firefox on first launch


CHANGELOG
---------

* **0.9** (29/01/2015)
  * Ported "Portable Firefox CX", an old app I made in 2006, to Swift.



LICENSE
-------

  _Copyright (C) 2015, Erin Casali_  
  _Licensed under **GNUv2 Opensource License**_


> _If I could wake up in a different place, at a different time, could I wake up as a different person?_
