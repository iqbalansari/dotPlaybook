import Control.Concurrent

import XMonad

-- Integration with gnome
import XMonad.Config.Gnome

-- For cycling workspaces
import XMonad.Actions.CycleWS
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

-- Smarter borders
import XMonad.Layout.NoBorders

-- avoid struts
import XMonad.Hooks.ManageDocks

import XMonad.ManageHook

-- Additional helpers for manage hooks
import XMonad.Hooks.ManageHelpers

import XMonad.Hooks.FadeInactive

import qualified XMonad.StackSet as W

import qualified Data.Map as M

-- Allows resizing from any corner of the window
import qualified XMonad.Actions.FlexibleResize as Flex

-- Hooks to run when window sets WM_URGENT
import XMonad.Hooks.UrgencyHook
import XMonad.Util.NamedWindows
import XMonad.Util.Run

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

myModMask = mod4Mask

myTerminal = "gnome-terminal"

myWorkspaces = ["shell", "emacs", "web", "chat", "vm"] ++ map show [6..9]

numPadKeys =
  [
    xK_KP_End, xK_KP_Down, xK_KP_Page_Down,
    xK_KP_Left, xK_KP_Begin,xK_KP_Right,
    xK_KP_Home, xK_KP_Up, xK_KP_Page_Up
  ]

-- Credits: http://permalink.gmane.org/gmane.comp.lang.haskell.xmonad/14812
-- From: http://lpaste.net/8970541507006169088
flipD :: Direction2D -> Direction2D
flipD x = case x of -- possibly wrong
            R -> U
            L -> D
            U -> L
            D -> R

changingDir :: (Direction2D -> Direction2D) -- ^ transform direction
      -> [(Direction2D, X ())]
      -> Direction2D -> X ()
changingDir t assocs cmd = Data.Foldable.sequence_ $ lookup (t cmd) assocs

withCurLayout :: (String -> r) -> X r
withCurLayout f = gets (f . description . W.layout . W.workspace . W.current . windowset)

isMirrored :: X Bool
isMirrored = withCurLayout (\x -> "Mirror" `isInfixOf` x :: Bool)

mirrorSensitive :: Direction2D -> X ()
mirrorSensitive d = do
    b <- isMirrored
    changingDir (if b then flipD else id) mirrorSensitiveAssocs d

mirrorSensitiveAssocs :: [(Direction2D, X ())]
mirrorSensitiveAssocs =
    [(L, sendMessage Shrink),
     (R, sendMessage Expand),
     (D, sendMessage MirrorShrink),
     (U, sendMessage MirrorExpand)]

myKeys = [
  -- Switching / moving windows to workspace
  ((myModMask,                               xK_n), nextWS),
  ((myModMask,                               xK_p), prevWS),
  ((myModMask .|. shiftMask,                 xK_n), shiftToNext),
  ((myModMask .|. shiftMask,                 xK_p), shiftToPrev),
  ((myModMask,                               xK_o), windows W.focusDown),
  ((myModMask .|. shiftMask,                 xK_o), windows W.swapDown),
  ((myModMask .|. controlMask .|. shiftMask, xK_n), shiftToNext >> nextWS),
  ((myModMask .|. controlMask .|. shiftMask, xK_p), shiftToPrev >> prevWS),
  ((myModMask,                               xK_b), toggleWS),
  ((myModMask,                               xK_f), sendMessage ToggleStruts),
  ((myModMask,                               xK_c), spawn "~/.xmonad/org-capture"),
  ((myModMask,                               xK_s), spawn "rofi -show window"),
  ((mod1Mask,                                xK_Tab), spawn "rofi -show window"),
  ((myModMask,                               xK_u), focusUrgent),

  -- Use alt + ctrl + t to launch terminal
  ((mod1Mask .|. controlMask, xK_t), spawn myTerminal),

    -- Use alt + ctrl + l to lock screen
  ((mod1Mask .|. controlMask, xK_l), spawn "gnome-screensaver-command -l"),

  -- Display a message using notify-send after reloading XMonad
  ((myModMask,                 xK_q), spawn "if type xmonad; then xmonad --recompile && xmonad --restart && notify-send 'XMonad reloaded'; else xmessage xmonad not in \\$PATH: \"$PATH\"; fi"),
  ((myModMask .|. shiftMask,   xK_q), spawn "gnome-session-quit")
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
    ((myModMask, xK_v ),       killAllOtherCopies), -- Make focused window always visible
    ((myModMask .|. shiftMask, xK_v ),  windows copyToAll) -- Toggle window state back
  ]

myMouseBindings = [
  -- Resize a window using any of the corners
  ((myModMask, button3), (\w -> focus w >> Flex.mouseResizeWindow w))
  ]

myLayouts = magnifierOff (dwmStyle shrinkText defaultTheme (smartBorders(avoidStruts(tiled ||| Mirror tiled ||| Accordion ||| simpleTabbed ||| Full))))
  where
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
  stringProperty "WM_NAME" =? "Hangouts"                                          -?> doShift "chat",
  stringProperty "WM_NAME" =? "*Org Capture*"                                     -?> doCenterFloat,
  stringProperty "WM_NAME" =? "Open Files"                                        -?> doCenterFloat,
  stringProperty "WM_NAME" =? "File Upload"                                       -?> doCenterFloat,
  stringProperty "WM_NAME" =? "Save As"                                           -?> doCenterFloat,
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
  className                =? "Zenity"                                            -?> doCenterFloat
  ] <+> composeAll [
  className =? "qemu-system-x86_64" --> doShift "vm",
  className =? "qemu-system-x86_64" --> doCenterFloat
  ]

-- Notify about activity in a window using notify send
-- Credits: [https://pbrisbin.com/posts/using_notify_osd_for_xmonad_notifications/]
data LibNotifyUrgencyHook = LibNotifyUrgencyHook deriving (Read, Show)

instance UrgencyHook LibNotifyUrgencyHook where
    urgencyHook LibNotifyUrgencyHook w = do
        name     <- getName w
        Just idx <- fmap (W.findTag w) $ gets windowset

        safeSpawn "notify-send" [show name, "workspace " ++ idx]

myFadeHook :: X ()
myFadeHook = fadeInactiveLogHook 0.9

wallpaperBackgroundTask :: IO ()
wallpaperBackgroundTask = do
  setRandomWallpaper ["/usr/share/backgrounds/", "$HOME/.backgrounds"]
  threadDelay (30 * 60 * 1000000)
  wallpaperBackgroundTask

main = do
  path       <- getEnv "PATH"
  home       <- getEnv "HOME"
  setEnv "PATH" (home ++ "/.local/bin/" ++ ":" ++ path)
  forkIO wallpaperBackgroundTask
  xmonad $ withUrgencyHook LibNotifyUrgencyHook $ (
     gnomeConfig {
         modMask     = myModMask,
         terminal    = myTerminal,
         workspaces  = myWorkspaces,
         layoutHook  = myLayouts,
         logHook     = myFadeHook <+> logHook gnomeConfig,
         manageHook  = myManagementHooks <+> manageHook gnomeConfig <+> manageDocks,
         startupHook = spawn "~/.xmonad/startup-hook" >> startupHook gnomeConfig
         }
     `additionalKeys` myKeys
     `additionalMouseBindings` myMouseBindings
     )
