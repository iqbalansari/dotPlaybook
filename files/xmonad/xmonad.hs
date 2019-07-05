import Control.Concurrent
import Control.Monad

import XMonad

-- Integration with gnome
import XMonad.Config.Gnome

-- For cycling workspaces
import XMonad.Actions.CycleWS
import XMonad.Actions.GroupNavigation

import XMonad.Actions.WithAll
import XMonad.Actions.GroupNavigation

-- Easier configuration of keybindings
import XMonad.Util.EZConfig

import XMonad.Prompt

-- Displaying wallpaper
import XMonad.Wallpaper

-- The layouts
import XMonad.Layout
import XMonad.Layout.ResizableTile
import XMonad.Layout.Accordion
import XMonad.Layout.Tabbed
import XMonad.Layout.Magnifier

-- avoid struts
import XMonad.Hooks.ManageDocks

import XMonad.ManageHook

-- Additional helpers for manage hooks
import XMonad.Hooks.ManageHelpers
import XMonad.Hooks.FadeInactive
import XMonad.Hooks.SetWMName
import XMonad.Hooks.Place
import XMonad.Hooks.EwmhDesktops

import qualified XMonad.StackSet as W

import qualified Data.Map as M

-- Allows resizing from any corner of the window
import qualified XMonad.Actions.FlexibleResize as Flex

-- Hooks to run when window sets WM_URGENT
import XMonad.Hooks.UrgencyHook
import XMonad.Util.NamedWindows
import XMonad.Util.Run
import XMonad.Util.NamedScratchpad

-- Needed for mirror sensitive resizing
import XMonad.Util.Types
import Data.Foldable
import Data.List

-- Swapping workspaces
import XMonad.Actions.SwapWorkspaces

-- Displaying DWM style decorations
import XMonad.Layout.DwmStyle

 -- Creating copies of windows
import XMonad.Actions.CopyWindow

import Graphics.X11.ExtraTypes.XF86

import System.Directory
import System.Environment
import XMonad.Actions.FloatKeys

myModMask = mod4Mask

myTerminal = "gnome-terminal"

myWorkspaces = ["terminal", "emacs", "web", "chat", "zoom", "vm"] ++ map show [7..9]

numPadKeys =
  [
    xK_KP_End, xK_KP_Down, xK_KP_Page_Down,
    xK_KP_Left, xK_KP_Begin,xK_KP_Right,
    xK_KP_Home, xK_KP_Up, xK_KP_Page_Up
  ]

myScratchpads = [
-- run htop in xterm, find it by title, use default floating window placement
    NS "terminal" "gnome-terminal --name terminal -- tmux set-option -g set-titles off \\; new-session" (name =? "Terminal") doCenterFloat,
    NS "notes" "emacsclient -ne '(progn (select-frame (make-frame (list (cons (quote name) \"*Notes*\") (cons (quote desktop-dont-save) t)))) (deft))'" (name =? "*Notes*") doCenterFloat
    ]
  where
    name = stringProperty "WM_NAME"

scratchPadName = "NSP"

nonScratchPad :: WSType
nonScratchPad = WSIs $ return ((scratchPadName /=) . W.tag)

getCurrentClassName = withWindowSet $ \set -> case  W.peek set of
  Just window -> runQuery className window
  Nothing -> return ""

switchOtherWindow direction = do
  name <- getCurrentClassName
  nextMatch direction (className =? name)

myKeys = [
  -- Switching / moving windows to workspace
  ((myModMask,                               xK_n), moveTo Next nonScratchPad),
  ((myModMask,                               xK_p), moveTo Prev nonScratchPad),
  ((myModMask .|. shiftMask,                 xK_n), shiftTo Next nonScratchPad),
  ((myModMask .|. shiftMask,                 xK_p), shiftTo Prev nonScratchPad),
  ((myModMask,                               xK_o), windows W.focusDown),
  ((myModMask .|. shiftMask,                 xK_o), windows W.swapDown),
  ((myModMask .|. controlMask .|. shiftMask, xK_n), shiftTo Next nonScratchPad >> moveTo Next nonScratchPad),
  ((myModMask .|. controlMask .|. shiftMask, xK_p), shiftTo Prev nonScratchPad >> moveTo Prev nonScratchPad),
  ((myModMask,                               xK_b), toggleWS' [scratchPadName]),
  ((myModMask,                               xK_f), sendMessage ToggleStruts),
  ((myModMask,                               xK_c), spawn "~/.xmonad/org-capture"),
  ((myModMask,                               xK_s), spawn "rofi -show window"),
  ((mod1Mask,                                xK_Tab), spawn "rofi -show window"),
  ((myModMask,                               xK_u), focusUrgent),
  ((myModMask .|. shiftMask,                 xK_t), sinkAll),

  -- Quickly switch to another window of the same application
  ((myModMask,                               xK_grave), switchOtherWindow Forward),
  ((myModMask,                               xK_asciitilde), switchOtherWindow Backward),

  ((myModMask .|. controlMask,               xK_t), namedScratchpadAction myScratchpads "terminal"),
  ((myModMask .|. controlMask,               xK_n), namedScratchpadAction myScratchpads "notes"),

  -- Use alt + ctrl + t to launch terminal
  ((mod1Mask .|. controlMask,                xK_t), spawn myTerminal),

    -- Use alt + ctrl + l to lock screen
  ((mod1Mask .|. controlMask, xK_l), spawn "gnome-screensaver-command -l"),

  -- Display a message using notify-send after reloading XMonad
  ((myModMask,                 xK_q), spawn "if type xmonad; then xmonad --recompile && xmonad --restart && notify-send 'XMonad reloaded'; else xmessage xmonad not in \\$PATH: \"$PATH\"; fi"),
  ((myModMask .|. shiftMask,   xK_q), spawn "gnome-session-quit")
  ]
  ++
  [
    -- Bindings for working with floating windows
    ((myModMask,                             xK_Left), withFocused (keysMoveWindow (-15, 0))),
    ((myModMask,                             xK_Right), withFocused (keysMoveWindow (15, 0))),
    ((myModMask,                             xK_Up), withFocused (keysMoveWindow (0, -15))),
    ((myModMask,                             xK_Down), withFocused (keysMoveWindow (0, 15))),
    ((myModMask,                             xK_equal), withFocused (keysResizeWindow (10, 10) (0.5, 0.5))),
    ((myModMask,                             xK_minus), withFocused (keysResizeWindow (-10, -10) (0.5, 0.5)))
  ]
  ++
  [
    -- Bind windows + numpad keys to move to a workspace, windows + shift + numpad keys to shift
    -- windows to workspace
    ((myModMask .|. m, k), windows $ f i) | (i, k) <- zip myWorkspaces numPadKeys, (f, m) <- [(W.greedyView, 0), (W.shift, shiftMask)]
  ]
  ++
  [
    -- Bind windows + shift + ctrl + number shift window to workspace numberth workspace and
    -- switch to workspace, similar to windows + shift + ctrl + right/left
    ((myModMask .|. controlMask .|. shiftMask, k), (windows $ W.shift i) >> (windows $ W.greedyView i)) | (i, k) <- zip myWorkspaces [xK_1 .. xK_9]
  ]
  ++
  [
    -- Bind windows + shift + ctrl + numpad keys to move window to a workspace and switch to it
    ((myModMask .|. shiftMask .|. controlMask, k), (windows $ W.shift i) >> (windows $ W.greedyView i)) | (i, k) <- zip myWorkspaces numPadKeys
  ]
  ++
  [
    ((myModMask .|. controlMask, k), (windows $ swapWithCurrent i)) | (i, k) <- zip myWorkspaces [xK_1 ..]
  ]
  ++
  [
    ((myModMask .|. controlMask, xK_m ), sendMessage Toggle)
  ]
  ++
  [
    ((myModMask, xK_v),                       windows copyToAll), -- Toggle window state back
    ((myModMask .|. shiftMask, xK_v ),       killAllOtherCopies)  -- Make focused window always visible
  ]

myMouseBindings = [
  -- Resize a window using any of the corners
  ((myModMask .|. shiftMask, button1), (\w -> focus w >> Flex.mouseResizeWindow w))
  ]

myLayoutHook = magnifierOff $ dwmStyle shrinkText defaultTheme $ avoidStruts $ standardLayout
  where
    standardLayout = tiled ||| Mirror tiled ||| Accordion ||| simpleTabbed ||| Full

    -- default tiling algorithm partitions the screen into two panes
    tiled   = ResizableTall nmaster delta ratio []

    -- The default number of windows in the master pane
    nmaster = 1

    -- Default proportion of screen occupied by master pane
    ratio   = 1/2

    -- Percent of screen to increment by when resizing panes
    delta   = 3/100

myManagementHooks :: ManageHook
myManagementHooks = composeOne [
  isDialog                                                                        -?> doFloat,
  isFullscreen                                                                    -?> doFullFloat,
  name                     =? "Hangouts"                                          -?> doShift "chat",
  name                     =? "*Org Capture*"                                     -?> doCenterFloat,
  name                     =? "Open Files"                                        -?> doCenterFloat,
  name                     =? "File Upload"                                       -?> doCenterFloat,
  name                     =? "Save As"                                           -?> doCenterFloat,
  resource                 =? "file_properties"                                   -?> doCenterFloat,
  resource                 =? "Dialog"                                            -?> doFloat,
  resource                 =? "update-manager"                                    -?> doFloat,
  className                =? "Xfce4-notifyd"                                     -?> doIgnore,
  className                =? "gnome-font-viewer"                                 -?> doCenterFloat,
  className                =? "Gcr-prompter"                                      -?> doCenterFloat,
  className                =? "Zenity"                                            -?> doCenterFloat,
  className                =? "File-roller"                                       -?> doCenterFloat,
  className                =? "Gnome-fallback-mount-helper"                       -?> doCenterFloat,
  className                =? "Display"                                           -?> doCenterFloat,
  className                =? "Artha"                                             -?> doCenterFloat,
  className                =? "Emacs"                                             -?> doShift "emacs",
  className                =? "Firefox"                                           -?> doShift "web",
  className                =? "Slack"                                             -?> doShift "chat",
  className                =? "Eog"                                               -?> doCenterFloat,
  className                =? "Zenity"                                            -?> doCenterFloat,
  className                =? "pritunl"                                           -?> doCenterFloat,
  className                =? "Gnome-calculator"                                  -?> doCenterFloat
  ] <+> composeAll [
  className =? "qemu-system-x86_64" --> doShift "vm",
  className =? "qemu-system-x86_64" --> doCenterFloat
  ] <+> composeAll [
  className =? "zoom" --> doShift "zoom",
  className =? "zoom" --> doCenterFloat
  ]
  where
    name = stringProperty "WM_NAME"

-- Notify about activity in a window using notify send
-- Credits: [https://pbrisbin.com/posts/using_notify_osd_for_xmonad_notifications/]
data LibNotifyUrgencyHook = LibNotifyUrgencyHook deriving (Read, Show)

instance UrgencyHook LibNotifyUrgencyHook where
    urgencyHook LibNotifyUrgencyHook w = do
        name     <- getName w
        Just idx <- fmap (W.findTag w) $ gets windowset

        safeSpawn "notify-send" [show name, "workspace " ++ idx]

myFadeHook :: X ()
myFadeHook = fadeOutLogHook $ fadeIf (isUnfocused <&&> liftM not shouldNotFade) 0.8

shouldNotFade = className =? "Xfce4-notifyd" <||> className =? "zoom"

wallpaperBackgroundTask :: IO ()
wallpaperBackgroundTask = do
  setRandomWallpaper ["/usr/share/backgrounds/", "$HOME/.backgrounds"]
  threadDelay (30 * 60 * 1000000)
  wallpaperBackgroundTask

main = do
  path       <- getEnv "PATH"
  home       <- getEnv "HOME"
  setEnv "PATH" (home ++ "/.local/bin/" ++ ":" ++ path)
  spawn "xrdb -merge ~/.Xresources"
  spawn "compton -c -C"
  forkIO wallpaperBackgroundTask
  xmonad $ withUrgencyHook LibNotifyUrgencyHook $ (
     gnomeConfig {
         modMask     = myModMask,
         terminal    = myTerminal,
         workspaces  = myWorkspaces,
         borderWidth = 0,
         layoutHook  = myLayoutHook,
         logHook     = myFadeHook <+> (ewmhDesktopsLogHookCustom namedScratchpadFilterOutWorkspace),
         manageHook  = namedScratchpadManageHook myScratchpads <+> placeHook placementPreferCenter <+> myManagementHooks <+> manageHook gnomeConfig <+> manageDocks,
         startupHook = spawn "~/.xmonad/startup-hook" >> setWMName "LG3D" >> startupHook gnomeConfig
         }
     `additionalKeys` myKeys
     `additionalMouseBindings` myMouseBindings
     )

  where
    placementPreferCenter = withGaps (16,0,16,0) (smart (0.5,0.5))
