# wAppbar

wAppbar is wNim implementation of Windows Application Desktop Bar (appbar), powered by 
[wnim](https://github.com/khchen/wNim) (Nim's Windows GUI Framework). wAppbar is wNim\'s wFrame extension, 
all wFrame methods (including layout) are accessible.

## Code Example

```nimrod
import wNim, wAppbar

let app = App()
let bar = Appbar(width=40, edge=abBottom)

let panel = Panel(bar)
let button = Button(panel, label="Close", size=(60, 30))

button.wEvent_Button do ():
   bar.delete()

bar.wEvent_Size do ():
   panel.layout:
      button:
         top == panel.top + 5
         right + 5 == panel.right
         bottom + 5 == panel.bottom
         width == 60

bar.show()

app.mainLoop()
```

If the code above is saved to demobar.nim you can compile it, as follows:

    nim c -d:release --opt:size --passL:-s --app:gui demobar.nim

## Construction, destruction, properties and methods of wAppbar

Constructor:

```nimrod
let bar = Appbar(width= [bar width], edge= [bar edge])
```

Destructor:

```nimrod
bar.delete()
```

Methods:

    show() - shows bar
    hide() - hides bar
    setFocus() - shows bar (even over fullscreen app) and set focus on it

Setters:

    setWidth(value: int) - change bar width (also bar.width = value syntax is possible)
    setEdge(value: wAppbarEdge) - change bar edge (also bar.edge = value syntax is possible)

Getters:

    getWidth(): int - retrieves width of bar (also bar.width syntax is possible)
	 getEdge(): wAppbarEdge - retrieves edge of bar (also bar.edge syntax is possible)
	 isShown - flag if bar is shown on screen (for example bar is not shown when fullscreen app is viewed)

## Install
With git on windows:

    nimble install https://github.com/zolern/wAppbar

Without git:

    1. Download and unzip this module (by click "Clone or download" button).
    2. Start a console, change current dir to the folder which include "wAppbar.nimble" file.
       (for example: C:\nim\wAppbar>)
    3. Run "nimble install"

For Windows XP compatibility, add:

    -d:useWinXP

## Q & A
### Q: Why I start this project?
In the first, I just wanted to write some code to test and prove wNim and winim libraries. Actually both are
just amazing, very easy to use, very well designed and documented (great work, Ward!) So, in my current project
I need desktop appbar and find that appbars are some kind tricky and not so easy to maintain - there are
several unexpected traps and non-documented issues with desktop appbars. I am proud that my wAppbar now works
like a charm on the last Windows 10 flavor but also even on Windows XP!

### Q: Why Nim/wNim?
I am huge fan of Nim language. After almost ten years developing with Visual C++ now Nim language for me is more 
than fresh air. My previous projects were Windows GUI applications based on Visual C++/MFC, but in the last several
years I am looking for better way to develop that kind of software. Actually I don't like Electron fat 
application, neither all the new Microsoft .Net technologies that are incompatible with Windows XP/2003. And finally
I found it - Nim with wNim/winim are my new favorite tools.

## License
Read license.txt for more details.

Copyright (c) 2018 Encho Topalov, Zolern. All rights reserved.
