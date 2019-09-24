#====================================================================
#
#               wAppbar - Desktop app bar with Nim/wNim's Windows GUI Framework
#                (c) Copyright 2018 Encho "Zolern" Topalov
#
#====================================================================

##  wAppbar is Windows Desktop Application Bar, based on wNim Windows Framework
import winim/[winimx, utils]
import wNim/[wApp, wFrame]
winimx currentSourcePath()

const
   wEvent_AppBar = wEvent_App + 1
   wTimerBarSetPos = 1
   wTimerBarOnFocus = 2

type
   wAppbarEdge* = enum
      ## App bar edge enum
      abLeft = 0, abTop, abRight, abBottom

   wAppbar = ref object of wFrame
      mBarWidth: int
      mEdge: wAppbarEdge
      mIsRegistered: bool
      mRect: RECT
      mShow: bool
      mOnTop: bool
      mOnFocus: bool
      mOnFullscreen: bool

proc getScreenScale(): float =
   # Evaluate screen scale factor
   var hdc = GetDC(0)
   let logicalScreenHeight = GetDeviceCaps(hdc, VERTRES)
   let physicalScreenHeight = GetDeviceCaps(hdc, DESKTOPVERTRES);
   result = float(physicalScreenHeight) / float(logicalScreenHeight)
   ReleaseDC(0, hdc)

proc rectMult(rc: RECT, factor: float = 1.0): RECT =
   # Expand/shrink rect coordinates by scale factor
   result = RECT(left: LONG(float(rc.left) * factor + 0.5),
                 right: LONG(float(rc.right) * factor + 0.5),
                 top: LONG(float(rc.top) * factor + 0.5),
                 bottom: LONG(float(rc.bottom) * factor + 0.5))

proc setOnTop(self: wAppbar, onTop: bool) =
   # Set/unset bar to be shown "on top"
   self.mOnTop = onTop
   self.startTimer(0.05, wTimerBarSetPos)

proc setOnFocus(self: wAppbar, onFocus: bool) =
   self.mOnFocus = onFocus
   self.startTimer(0.075, wTimerBarOnFocus)

proc appbar_Data(self: wAppbar): APPBARDATA =
   # helper to prepary APPBARDATA struct
   return APPBARDATA(cbSize: DWORD(sizeof(APPBARDATA)), hWnd: self.getHandle(), lParam: 0)

proc appbar_Edge(self: wAppbar): UINT =
   # convert abBarEdge enum to SHAppBarMessage constants
   case self.mEdge
   of abLeft: ABE_LEFT
   of abTop: ABE_TOP
   of abRight: ABE_RIGHT
   of abBottom: ABE_BOTTOM

proc appbar_Register(self: wAppbar, register: bool): bool =
   # Register/unregister app bar
   var abd = appbar_Data(self)

   if register:
      # Provide an identifier for notification messages.
      abd.uCallbackMessage = wEvent_AppBar;

      # Register the appbar.
      if SHAppBarMessage(ABM_NEW, &abd) != TRUE:
         return false

      abd.lParam = ABS_ALWAYSONTOP
      SHAppBarMessage(ABM_SETSTATE, &abd)
   else:
      # Unregister the appbar.
      SHAppBarMessage(ABM_REMOVE, &abd)

   return true

proc appbar_Resize(self: wAppbar) =
   # Notify app bar is resized/moved
   var abd = appbar_Data(self)
   SHAppBarMessage(ABM_WINDOWPOSCHANGED, &abd)

proc appbar_SetPos(self: wAppbar) =
   # Calculate position and size of app bar
   var abd = appbar_Data(self)
   let abWidth = if self.mShow: LONG(self.mBarWidth) else: 0

   abd.rc = RECT(left: 0, top: 0, right: GetSystemMetrics(SM_CXSCREEN), bottom: GetSystemMetrics(SM_CYSCREEN))

   case self.mEdge
   of abLeft: abd.rc.right = abWidth
   of abTop:  abd.rc.bottom = abWidth
   of abRight: abd.rc.left = abd.rc.right - abWidth
   of abBottom: abd.rc.top = abd.rc.bottom - abWidth

   abd.uEdge = appbar_Edge(self)

   let scale = getScreenScale()

   # Scale app bar rect (SHAAppBarMessage is not DPI awareness)
   abd.rc = rectMult(abd.rc, scale)

   # Query the system for an approved size and position.
   SHAppBarMessage(ABM_QUERYPOS, &abd);

   abd.rc = rectMult(abd.rc, 1 / scale)

   # Adjust the rectangle, depending on the edge to which the appbar is anchored.
   case self.mEdge
   of abLeft: abd.rc.right = abd.rc.left + abWidth
   of abRight: abd.rc.left = abd.rc.right - abWidth
   of abTop: abd.rc.bottom = abd.rc.top + abWidth
   of abBottom: abd.rc.top = abd.rc.bottom - abWidth

   # Pass the final bounding rectangle to the shell.
   abd.rc = rectMult(abd.rc, scale)
   SHAppBarMessage(ABM_SETPOS, &abd);

   # Get correctly scaled rect from shell
   self.mRect = rectMult(abd.rc, 1 / scale)

   # Postpone app bar reposition
   self.startTimer(0.05, wTimerBarSetPos)

proc appbar_Activate(self: wAppbar) =
   # notify app bar is activated/inactivated
   var abd = appbar_Data(self)
   SHAppBarMessage(ABM_ACTIVATE, &abd)

proc appbar_Notify(self: wAppbar, wParam: WPARAM, lParam: LPARAM) =
   # processing notifications to app bar
   var abd = appbar_Data(self)
   var uState: UINT

   case int wParam
   of ABN_STATECHANGE:
      # Check to see if the taskbar's always-on-top state has changed
      # and, if it has, change the appbar's state accordingly.
      uState = UINT SHAppBarMessage(ABM_GETSTATE, &abd)
      self.setOnTop((uState and ABS_ALWAYSONTOP) != 0)
   of ABN_FULLSCREENAPP:
      # A full-screen application has started, or the last full-screen
      # application has closed. Set the appbar's z-order appropriately.
      if  lParam != 0: # full-screen app is started
         self.mOnFullscreen = true
         self.setOnTop(false)
      else:
         self.mOnFullscreen = false
         self.setOnTop(true)
   of ABN_WINDOWARRANGE:
      # Hide bar when Window cascade, tile, etc is processed
      ShowWindow(self.getHandle(), if lParam != 0: SW_HIDE else: SW_SHOWNA)
   of ABN_POSCHANGED:
      # The taskbar or another appbar has changed its size or position.
      appbar_SetPos(self)
   else:
      discard

proc show*(self: wAppbar, flag = true) {.inline.} =
   ## Show/Hide app bar routine
   self.mShow = flag
   appbar_SetPos(self)
   appbar_Resize(self)

proc hide*(self: wAppbar) {.inline.} =
   ## hide app bar
   show(self, false)

proc isShown*(self: wAppbar): bool {.inline.} =
   ## check does appbar really is shown (even above fullscreen app)
   self.mShow and (self.mOnTop or self.mOnFocus)

proc setWidth*(self: wAppbar, width: int) {.inline.}  =
   ## change app bar width
   self.mBarWidth = width
   show(self, self.mShow)

proc getWidth*(self: wAppbar): int  {.inline.} = self.mBarWidth
   ## retrieve app bar width

proc width*(self: wAppbar): int  {.inline.} = self.mBarWidth
   ## property-like syntax (appbar.width)

proc `width=`*(self: wAppbar, value: int) {.inline.}  =
   ## enable property-like syntax (appbar.width = <value>)
   self.setWidth(value)

proc setEdge*(self: wAppbar, edge: wAppbarEdge) {.inline.}  =
   ## change appbar edge
   self.mEdge = edge
   show(self, self.mShow)

proc getEdge*(self: wAppbar): wAppbarEdge {.inline.} = self.mEdge
   ## retrieve appbar edge

proc edge*(self: wAppbar): wAppbarEdge {.inline.}  = self.mEdge
   ## property-like syntax (appbar.edge)
proc `edge=`*(self: wAppbar, value: wAppbarEdge) {.inline.}  =
   ## enable property-like syntax (appbar.edge = <value>)
   self.setEdge(value)

proc setFocus*(self: wAppbar) =
   ## Shows and activate app bar (even over fullscreen app)
   self.setOnFocus(true)
   self.show(true)

proc final*(self: wAppbar) =
   ## Default finalizer for wWindow.
   wFrame(self).final()

proc delete*(self: wAppbar) =
   ## Unregister app bar and destroys it
   if self.mIsRegistered:
      discard appbar_Register(self, false)

   self.mIsRegistered = false
   wFrame(self).delete()

proc init(self: wAppbar, width: int, edge: wAppbarEdge) =
   ## Initialize app bar and register it
   wFrame(self).init(title="", size = (width, width),  style = wPopup or wHideTaskbar)
   self.mBarWidth = width
   self.mEdge = edge
   self.mShow = false
   self.mOnTop = true
   self.mOnFullscreen = false

   self.wEvent_Size do ():
      appbar_Resize(self)

   self.wEvent_Activate do (event: wEvent):
      if event.wParam != 0:
         appbar_Activate(self)
      else:
         self.setOnFocus(false)

   self.wEvent_AppBar do (event: wEvent):
      appbar_Notify(self, event.wParam, event.lParam)

   self.wEvent_Timer do (event: wEvent):
      self.stopTimer(event.timerId)
      let rc = self.mRect

      if self.mShow and (self.mOnTop or self.mOnFocus):
         ShowWindow(self.getHandle(), SW_SHOWNA)
         SetWindowPos(self.getHandle(), HWND_TOPMOST, 0, 0, 0, 0, UINT(SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE))
         MoveWindow(self.getHandle(), rc.left, rc.top, rc.right - rc.left, rc.bottom - rc.top, TRUE)

         if (event.timerId == wTimerBarOnFocus) and self.mOnFocus:
            SetForegroundWindow(self.getHandle())
            SetActiveWindow(self.getHandle())
            wFrame(self).setFocus()
      else:
         ShowWindow(self.getHandle(), SW_HIDE)

   self.mIsRegistered = appbar_Register(self, true)

proc Appbar*(width: int, edge: wAppbarEdge): wAppbar {.inline.} =
   ## Constructor
   new(result, final)
   result.init(width, edge)
