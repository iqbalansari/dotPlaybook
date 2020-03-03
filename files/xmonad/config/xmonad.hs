{-# LANGUAGE DeriveDataTypeable #-}
import System.Directory
import System.Environment

import Control.Concurrent
import Control.Monad

import Data.Foldable
import Data.List
import Data.Ratio
import Data.Monoid
import Data.Maybe (listToMaybe)
import Data.Set as S
import qualified Data.Map as M

import Graphics.X11.ExtraTypes.XF86

import XMonad
import XMonad.ManageHook
import XMonad.Prompt
import XMonad.Wallpaper
import XMonad.Util.EZConfig
import qualified XMonad.StackSet as W

import XMonad.Config.Gnome

import XMonad.Actions.CycleWS
import XMonad.Actions.GroupNavigation
import XMonad.Actions.WithAll
import XMonad.Actions.SpawnOn
import XMonad.Actions.CopyWindow
import XMonad.Actions.SwapWorkspaces
import XMonad.Actions.FloatKeys
import qualified XMonad.Actions.FlexibleResize as Flex

import XMonad.Layout
import XMonad.Layout.ResizableTile
import XMonad.Layout.Magnifier
import XMonad.Layout.Spacing
import XMonad.Layout.DwmStyle
import XMonad.Layout.Drawer
import XMonad.Layout.Tabbed
import XMonad.Layout.ToggleLayouts
import XMonad.Layout.PerWorkspace

import XMonad.Hooks.ManageDocks
import XMonad.Hooks.ManageHelpers
import XMonad.Hooks.FadeInactive
import XMonad.Hooks.SetWMName
import XMonad.Hooks.Place
import XMonad.Hooks.EwmhDesktops
import XMonad.Hooks.UrgencyHook

import XMonad.Util.NamedWindows
import XMonad.Util.Run
import XMonad.Util.NamedScratchpad
import XMonad.Util.Types

import qualified XMonad.Util.ExtensibleState as XS

-- The following code ensures that floating windows that are at currently
-- focused are at the top, it treats notification windows especially in that
-- they are always at top

-- Extension to store the notification windows
data NotificationWindows = NotificationWindows (S.Set Window) deriving (Read, Show, Typeable)
instance ExtensionClass NotificationWindows where
  initialValue = NotificationWindows (S.empty)
  extensionType = PersistentExtension

-- Check if window has the given property of type Atom
hasAtomProperty :: Window -> String -> String -> X Bool
hasAtomProperty window property value = do
  valueAtom <- getAtom value
  property <- getProp32s property window
  return $ case property of
    Just values -> fromIntegral valueAtom `elem` values
    _ -> False

-- Keep track of notification windows
trackNotificationWindowsHook :: Event -> X All
trackNotificationWindowsHook (MapNotifyEvent {ev_window = window}) = do
  NotificationWindows windows <- XS.get
  isNotification <- hasAtomProperty window "_NET_WM_WINDOW_TYPE" "_NET_WM_WINDOW_TYPE_NOTIFICATION"

  if isNotification
    -- If this is a notification window remember it
    then XS.put (NotificationWindows (S.insert window windows))
    else return ()

  return $ All True

trackNotificationWindowsHook (UnmapEvent {ev_window = window}) = do
  NotificationWindows windows <- XS.get

  -- Window unmapped forget it
  XS.put (NotificationWindows (S.delete window windows))

  return $ All True

trackNotificationWindowsHook _ = return $ All True

-- Run as part of logHook, this moves the currently selected float window to the
-- top, the only exception notification windows which will always stay at top
keepFloatsOnTopHook :: X ()
keepFloatsOnTopHook = do
  windowSet <- gets windowset
  notificationWindows <- XS.get :: X NotificationWindows

  let
    raiseWindowMaybe windowSet window =
      if M.member window $ W.floating windowSet
      then withDisplay $ \display -> io $ raiseWindow display window
      else return ()

    raiseWindows [] = return ()

    raiseWindows (window:windows) = withDisplay $ \display -> do
      io $ raiseWindow display window
      raiseWindows windows
    in

    do
      case W.peek windowSet of
        Just window -> raiseWindowMaybe windowSet window
        Nothing -> return ()

      case notificationWindows of
        NotificationWindows set -> raiseWindows (S.toList set)
        _ -> return ()

myModMask = mod4Mask

myTerminal = "st"

myWorkspaces = ["terminal", "emacs", "web", "chat", "zoom", "vm"] ++ Data.List.map show [7..8] ++ ["reading"]

numPadKeys =
  [
    xK_KP_End, xK_KP_Down, xK_KP_Page_Down,
    xK_KP_Left, xK_KP_Begin,xK_KP_Right,
    xK_KP_Home, xK_KP_Up, xK_KP_Page_Up
  ]

scratchPadName = "NSP"

nonScratchPad :: WSType
nonScratchPad = WSIs $ return ((scratchPadName /=) . W.tag)

myScratchpads = [
    NS "files" "nautilus --class scratch-files" (className =? "scratch-files") nonFloating,
    NS "htop" "st -t scratch-htop -e htop" (name =? "scratch-htop") doCenterFloat,
    NS "notes" "emacsclient -ne '(progn (select-frame (make-frame (list (cons (quote name) \"*Notes*\") (cons (quote desktop-dont-save) t)))) (deft))'" (name =? "*Notes*") nonFloating,
    NS "terminal" "st -t scratch-terminal -e tmux set-option -g set-titles off \\; new-session -A -s scratch" (name =? "scratch-terminal") doCenterFloat,
    NS "zeal" "zeal" (className =? "Zeal") doCenterFloat
    ]
  where
    name = stringProperty "WM_NAME"

focusScratchpadOrBringToWorkspace :: NamedScratchpads -- ^ Named scratchpads configuration
                                  -> String           -- ^ Scratchpad name
                                  -> X ()

findByName :: NamedScratchpads -> String -> Maybe NamedScratchpad
findByName c s = listToMaybe $ Data.List.filter ((s==) . name) c

focusScratchpadOrBringToWorkspace confs name =
  let conf = findByName confs name in
    case conf of
      Just conf -> do
          windowSet <- gets windowset
          case W.peek windowSet of
            Just window -> do
              matches <- runQuery (query conf) window
              filterCurrent <- filterM (runQuery (query conf))
                                        ((maybe [] W.integrate . W.stack . W.workspace . W.current) windowSet)
              if matches
                then namedScratchpadAction confs name
                else case listToMaybe filterCurrent of
                       Just window -> windows (W.focusWindow window)
                       Nothing -> namedScratchpadAction confs name
            Nothing -> return ()
      Nothing -> return ()


getCurrentClassName = withWindowSet $ \set -> case  W.peek set of
  Just window -> runQuery className window
  Nothing -> return ""

switchOtherWindow :: Direction -> X ()
switchOtherWindow direction = do
  name <- getCurrentClassName
  nextMatch direction (className =? name)

centerWindow :: X ()
centerWindow = do
  rect <- fmap (screenRect . W.screenDetail . W.current) (gets windowset)
  withFocused (keysMoveWindowTo (centerPosition (rect_width rect), centerPosition (rect_height rect)) (1%2, 1%2))
  where
    centerPosition dimension = fromIntegral (dimension `div` 2)

fullScreenWindow :: X ()
fullScreenWindow = do
  windowSet <- gets windowset
  let
    fullScreenWindow' windowSet window =
      do
        if M.member window $ W.floating windowSet
          then windows (W.sink window)
          else return ()

        sendMessage (XMonad.Layout.ToggleLayouts.Toggle "Full")

    centerPosition dimension = fromIntegral (dimension `div` 2) in

    case W.peek windowSet of
      Just window -> fullScreenWindow' windowSet window
      Nothing -> return ()

resizeWindowUniformly :: Int -> G -> X ()
resizeWindowUniformly widthChange position =
  withDisplay $ \display -> do
    withFocused $ \window -> do
      win_attrs <- io $ getWindowAttributes display window
      let width  = wa_width win_attrs
          height = wa_height win_attrs
          aspectRatio = (fromIntegral height) / (fromIntegral width)
          heightChange = floor $ aspectRatio * (fromIntegral widthChange)
        in
        keysResizeWindow (fromIntegral widthChange, fromIntegral heightChange) position window


myKeys =
  [
    -- Switching / moving windows to workspace
    ((myModMask,                               xK_n), moveTo Next nonScratchPad),
    ((myModMask,                               xK_p), moveTo Prev nonScratchPad),
    ((myModMask .|. shiftMask,                 xK_n), shiftTo Next nonScratchPad),
    ((myModMask .|. shiftMask,                 xK_p), shiftTo Prev nonScratchPad),
    ((myModMask .|. controlMask .|. shiftMask, xK_n), shiftTo Next nonScratchPad >> moveTo Next nonScratchPad),
    ((myModMask .|. controlMask .|. shiftMask, xK_p), shiftTo Prev nonScratchPad >> moveTo Prev nonScratchPad),
    ((myModMask,                               xK_b), toggleWS' [scratchPadName]),
    ((myModMask,                               xK_u), focusUrgent),

    -- Moving between windows and swapping them
    ((myModMask,                               xK_o), windows W.focusDown),
    ((myModMask .|. shiftMask,                 xK_o), windows W.swapDown),

    -- Make copy of the current window on all workspaces
    ((myModMask, xK_y),                       windows copyToAll), -- Make focused window always visible
    ((myModMask .|. shiftMask, xK_y),         killAllOtherCopies), -- Toggle window state back

    -- Manipulating the layouts
    ((myModMask,                               xK_d), sendMessage ToggleStruts),
    ((myModMask .|. shiftMask,                 xK_f), fullScreenWindow),
    ((myModMask .|. shiftMask,                 xK_m ), sendMessage XMonad.Layout.Magnifier.Toggle),
    ((myModMask .|. shiftMask,                 xK_t), sinkAll),

    -- Spawn a terminal in the current workspace
    ((mod1Mask  .|. controlMask,               xK_t), spawnHere myTerminal),
    ((myModMask .|. shiftMask,                 xK_Return), spawnHere myTerminal),

    -- Quickly switch to another window of the same application
    ((myModMask,                               xK_grave), switchOtherWindow Forward),
    ((myModMask,                               xK_asciitilde), switchOtherWindow Backward),
    ((mod1Mask,                               xK_Tab), nextMatch Backward (return True)),
    ((mod1Mask .|. shiftMask,                 xK_Tab), nextMatch Forward (return True)),

    -- Applications
    ((myModMask .|. controlMask,               xK_c), spawn "~/.xmonad/org-capture"),
    ((myModMask .|. controlMask,               xK_f), namedScratchpadAction myScratchpads "files"),
    ((myModMask .|. controlMask,               xK_h), namedScratchpadAction myScratchpads "htop"),
    ((myModMask .|. controlMask,               xK_n), focusScratchpadOrBringToWorkspace myScratchpads "notes"),
    ((myModMask .|. controlMask,               xK_t), namedScratchpadAction myScratchpads "terminal"),
    ((myModMask .|. controlMask,               xK_z), namedScratchpadAction myScratchpads "zeal"),

    -- Rofi
    ((myModMask,                               xK_s), spawn "rofi -show window"),

    -- Locking screen
    ((mod1Mask .|. controlMask,                xK_l), spawn "dbus-send --type=method_call --dest=org.gnome.ScreenSaver /org/gnome/ScreenSaver org.gnome.ScreenSaver.Lock"),

    -- Reload XMonad
    ((myModMask,                               xK_q), spawn "if type xmonad; then xmonad --recompile && xmonad --restart && notify-send 'XMonad reloaded'; else xmessage xmonad not in \\$PATH: \"$PATH\"; fi"),
    ((myModMask .|. shiftMask,                 xK_q), spawn "gnome-session-quit")
  ]
  ++
  [
    -- Bind windows + shift + ctrl + number shift window to nth workspace and
    -- switch to workspace, similar to windows + shift + ctrl + right/left
    ((myModMask .|. controlMask .|. shiftMask, k), (windows $ W.greedyView i . W.shift i)) | (i, k) <- zip myWorkspaces [xK_1 .. xK_9]
  ]
  ++
  [
    -- Swapping workspaces
    ((myModMask .|. controlMask, k), (windows $ swapWithCurrent i)) | (i, k) <- zip myWorkspaces [xK_1 ..]
  ]
  ++
  [
    -- Bindings for working with floating windows
    -- Float a window
    ((myModMask,                                xK_f), withFocused $ keysResizeWindow (0, 0) (1%2, 1%2)),
    -- Move the window to the center
    ((myModMask,                                xK_c), centerWindow),
    -- Moving floating windows
    ((myModMask,                                xK_Left), withFocused (keysMoveWindow (-15, 0))),
    ((myModMask,                                xK_Right), withFocused (keysMoveWindow (15, 0))),
    ((myModMask,                                xK_Up), withFocused (keysMoveWindow (0, -15))),
    ((myModMask,                                xK_Down), withFocused (keysMoveWindow (0, 15))),
    ((myModMask .|. shiftMask,                  xK_Left), withFocused (keysMoveWindow (-150, 0))),
    ((myModMask .|. shiftMask,                  xK_Right), withFocused (keysMoveWindow (150, 0))),
    ((myModMask .|. shiftMask,                  xK_Up), withFocused (keysMoveWindow (0, -150))),
    ((myModMask .|. shiftMask,                  xK_Down), withFocused (keysMoveWindow (0, 150))),
    -- Resizing floating windows in one axis
    ((myModMask .|. controlMask,                xK_Left), withFocused (keysResizeWindow (-10, 0) (0.5, 0.5))),
    ((myModMask .|. controlMask,                xK_Right), withFocused (keysResizeWindow (10, 0) (0.5, 0.5))),
    ((myModMask .|. controlMask,                xK_Up), withFocused (keysResizeWindow (0, 10) (0.5, 0.5))),
    ((myModMask .|. controlMask,                xK_Down), withFocused (keysResizeWindow (0, -10) (0.5, 0.5))),
    ((myModMask .|. controlMask .|. shiftMask,  xK_Left), withFocused (keysResizeWindow (-150, 0) (0.5, 0.5))),
    ((myModMask .|. controlMask .|. shiftMask,  xK_Right), withFocused (keysResizeWindow (150, 0) (0.5, 0.5))),
    ((myModMask .|. controlMask .|. shiftMask,  xK_Up), withFocused (keysResizeWindow (0, 150) (0.5, 0.5))),
    ((myModMask .|. controlMask .|. shiftMask,  xK_Down), withFocused (keysResizeWindow (0, -150) (0.5, 0.5))),
    -- Resize respecting the current aspect ratio (as much as possible)
    ((myModMask,                                xK_equal), resizeWindowUniformly 10 (0.5, 0.5)),
    ((myModMask,                                xK_minus), resizeWindowUniformly (-10) (0.5, 0.5)),
    ((myModMask .|. shiftMask,                  xK_equal), resizeWindowUniformly 150 (0.5, 0.5)),
    ((myModMask .|. shiftMask,                  xK_minus), resizeWindowUniformly (-150) (0.5, 0.5))
  ]
  ++
  [
    -- Making numpad keys behavior similar to normal number keys
    -- Bind windows + numpad keys to move to a workspace, windows + shift + numpad keys to shift
    -- windows to workspace, windows + shift + control + numpad keys to shift and move to a workspace
    ((myModMask .|. mask, key), windows $ func index) |
       (index, key) <- zip myWorkspaces numPadKeys,
       (mask, func) <- [(0, W.greedyView), (shiftMask, W.shift), (shiftMask .|. controlMask, \i -> W.greedyView i . W.shift i)]
  ]

myMouseBindings = [
  -- Resize a window using any of the corners
  ((myModMask .|. shiftMask, button1), (\w -> focus w >> Flex.mouseResizeWindow w))
  ]

myLayoutHook = magnifierOff $ dwmStyle shrinkText defaultTheme $ layoutWithFullscreen
  where
    layoutWithFullscreen = drawer `onLeft` (toggleLayouts Full (avoidStruts $ standardLayout))

    standardLayout = onWorkspace "reading" simpleTabbed $ (tiled ||| Mirror tiled ||| Full)

    -- default tiling algorithm partitions the screen into two panes
    tiled   = smartSpacing 5 $ ResizableTall nmaster delta ratio []

    drawer  = simpleDrawer 0.0 0.3 (Title "*Notes*")

    -- The default number of windows in the master pane
    nmaster = 1

    -- Default proportion of screen occupied by master pane
    ratio   = 1/2

    -- Percent of screen to increment by when resizing panes
    delta   = 3/100

isNotification = isInProperty "_NET_WM_WINDOW_TYPE" "_NET_WM_WINDOW_TYPE_DIALOG"

myManagementHooks :: ManageHook
myManagementHooks = composeOne [
  isDialog                                                                        -?> doFloat,
  isFullscreen                                                                    -?> doFullFloat,
  name                     =? "Hangouts"                                          -?> doShift "chat",
  name                     =? "*Org Capture*"                                     -?> doCenterFloat,
  name                     =? "Open Files"                                        -?> doCenterFloat,
  name                     =? "File Upload"                                       -?> doCenterFloat,
  name                     =? "Save As"                                           -?> doCenterFloat,
  name                     =? "scratch-terminal"                                  -?> idHook,
  name                     =? "scratch-htop"                                      -?> idHook,
  name                     =? "*Notes*"                                           -?> idHook,
  resource                 =? "file_properties"                                   -?> doCenterFloat,
  resource                 =? "Dialog"                                            -?> doFloat,
  resource                 =? "update-manager"                                    -?> doFloat,
  resource                 =? "Gimp"                                              -?> doFloat,
  className                =? "gnome-font-viewer"                                 -?> doCenterFloat,
  className                =? "Gcr-prompter"                                      -?> doCenterFloat,
  className                =? "Zenity"                                            -?> doCenterFloat,
  className                =? "File-roller"                                       -?> doCenterFloat,
  className                =? "Gnome-fallback-mount-helper"                       -?> doCenterFloat,
  className                =? "Display"                                           -?> doCenterFloat,
  className                =? "Artha"                                             -?> doCenterFloat,
  className                =? "St"                                                -?> doShift "terminal",
  className                =? "Emacs"                                             -?> doShift "emacs",
  className                =? "Firefox"                                           -?> doShift "web",
  className                =? "Slack"                                             -?> doShift "chat",
  className                =? "Eog"                                               -?> doCenterFloat,
  className                =? "Zenity"                                            -?> doCenterFloat,
  className                =? "pritunl"                                           -?> doCenterFloat,
  className                =? "Gnome-calculator"                                  -?> doCenterFloat,
  className                =? "Qalculate-gtk"                                     -?> doCenterFloat,
  isNotification                                                                  -?> doIgnore
  ] <+> composeAll [
  className =? "qemu-system-x86_64" --> doShift "vm",
  className =? "qemu-system-x86_64" --> doCenterFloat
  ] <+> composeAll [
  className =? "zoom" --> doShift "zoom",
  className =? "zoom" --> doFloat
  ]
  where
    name       = stringProperty "WM_NAME"

-- Notify about activity in a window using notify send
-- Credits: [https://pbrisbin.com/posts/using_notify_osd_for_xmonad_notifications/]
data LibNotifyUrgencyHook = LibNotifyUrgencyHook deriving (Read, Show)

instance UrgencyHook LibNotifyUrgencyHook where
    urgencyHook LibNotifyUrgencyHook w = do
        name     <- getName w
        Just idx <- fmap (W.findTag w) $ gets windowset

        safeSpawn "notify-send" [show name, "workspace " ++ idx]

myFadeHook :: X ()
myFadeHook =
  fadeOutLogHook $ fadeIf (isUnfocused <&&> liftM not shouldNotFade) 0.8
  where
    shouldNotFade = isNotification <||> className =? "zoom"

wallpaperBackgroundTask :: IO ()
wallpaperBackgroundTask = do
  setRandomWallpaper ["/usr/share/backgrounds/", "$HOME/.backgrounds"]
  threadDelay (30 * 60 * 1000000)
  wallpaperBackgroundTask

main = do
  path       <- getEnv "PATH"
  home       <- getEnv "HOME"
  setEnv "PATH" (home ++ "/.local/bin/" ++ ":" ++ path)
  -- Merge Xresources file, need to this since LightDM merges
  -- Xresources using -nocpp option [https://bugs.launchpad.net/lightdm/+bug/1084885]
  -- thus any preprocessor statements are ignored
  spawn "xrdb -merge ~/.Xresources"
  forkIO wallpaperBackgroundTask
  xmonad $ withUrgencyHook LibNotifyUrgencyHook $ (
     gnomeConfig {
         modMask         = myModMask,
         terminal        = myTerminal,
         workspaces      = myWorkspaces,
         borderWidth     = 0,
         handleEventHook = handleEventHook gnomeConfig <+> fullscreenEventHook <+> trackNotificationWindowsHook,
         layoutHook      = myLayoutHook,
         logHook         = historyHook <+> myFadeHook <+> keepFloatsOnTopHook <+> ewmhDesktopsLogHookCustom namedScratchpadFilterOutWorkspace,
         manageHook      = manageSpawn <+> namedScratchpadManageHook myScratchpads <+> placeHook placementPreferCenter <+> myManagementHooks <+> manageHook gnomeConfig <+> manageDocks,
         startupHook     = spawn "~/.xmonad/startup-hook" >> setWMName "LG3D" >> startupHook gnomeConfig
         }
     `additionalKeys` myKeys
     `additionalMouseBindings` myMouseBindings
     )

  where
    placementPreferCenter = withGaps (16,0,16,0) (smart (0.5,0.5))
