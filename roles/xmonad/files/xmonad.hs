import XMonad

-- Integration with gnome
import XMonad.Config.Gnome

-- For cycling workspaces
import XMonad.Actions.CycleWS

-- Easier configuration of keybindings
import XMonad.Util.EZConfig

import XMonad.Prompt

-- Going to a window
import XMonad.Prompt.Window

-- The layouts
import XMonad.Layout
import XMonad.Layout.ResizableTile
import XMonad.Layout.Grid

-- Smarter borders
import XMonad.Layout.NoBorders

-- avoid struts
import XMonad.Hooks.ManageDocks

import XMonad.ManageHook

-- Additional helpers for manage hooks
import XMonad.Hooks.ManageHelpers

import qualified XMonad.StackSet as W

import qualified Data.Map as M

-- Allows resizing from any corner of the window
import qualified XMonad.Actions.FlexibleResize as Flex

-- Hooks to run when window sets WM_URGENT
import XMonad.Hooks.UrgencyHook
import XMonad.Util.NamedWindows
import XMonad.Util.Run

myModMask = mod4Mask

myTerminal = "uxterm"

myWorkspaces = ["shell", "emacs", "web", "chat", "vm"] ++ map show [6..9]

numPadKeys =
  [
    xK_KP_End, xK_KP_Down, xK_KP_Page_Down,
    xK_KP_Left, xK_KP_Begin,xK_KP_Right,
    xK_KP_Home, xK_KP_Up, xK_KP_Page_Up
  ]

myKeys = [
  -- Switching / moving windows to workspace
  ((myModMask,               xK_Right), nextWS),
  ((myModMask,               xK_Left), prevWS),
  ((myModMask .|. shiftMask, xK_Right), shiftToNext >> nextWS),
  ((myModMask .|. shiftMask, xK_Left), shiftToPrev >> prevWS),
  ((myModMask,               xK_z), toggleWS),
  ((myModMask,               xK_c), spawn "~/.xmonad/org-capture"),

  -- Use alt + ctrl + t to launch terminal
  ((mod1Mask .|. controlMask, xK_t), spawn myTerminal),

  -- Display a message using notify-send after reloading XMonad
  ((myModMask,                 xK_q), spawn "if type xmonad; then xmonad --recompile && xmonad --restart && notify-send 'XMonad reloaded'; else xmessage xmonad not in \\$PATH: \"$PATH\"; fi")
  ]
  ++
  [
    -- Bind windows + shift + alt + number shift window to workspace numberth workspace and
    -- switch to workspace, similar to windows + shift + right/left
    ((myModMask .|. shiftMask .|. mod1Mask, k), (windows $ W.shift i) >> (windows $ W.greedyView i)) | (i, k) <- zip myWorkspaces [xK_1 .. xK_9]
  ]
  ++
  [
    -- Bind windows + numpad keys to move to a workspace, windows + shift + numpad keys to shift
    -- windows to workspace
    ((myModMask .|. m, k), windows $ f i) | (i, k) <- zip myWorkspaces numPadKeys, (f, m) <- [(W.greedyView, 0), (W.shift, shiftMask)]
  ]
  ++
  [
  -- Bind windows + shift + alt + numpad keys to move window to a workspace and switch to it
    ((myModMask .|. shiftMask .|. mod1Mask, k), (windows $ W.shift i) >> (windows $ W.greedyView i)) | (i, k) <- zip myWorkspaces numPadKeys
  ]
  
myMouseBindings = [
  -- Resize a window using any of the corners
  ((myModMask, button3), (\w -> focus w >> Flex.mouseResizeWindow w))
  ]

myLayouts = smartBorders(avoidStruts(tiled ||| Mirror tiled ||| Grid ||| Full))
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
  stringProperty "WM_NAME" =? "Hangouts"          -?> doShift "chat",
  stringProperty "WM_NAME" =? "*Org Capture*"     -?> doCenterFloat,
  stringProperty "WM_NAME" =? "Open Files"        -?> doCenterFloat,
  resource                 =? "file_properties"   -?> doCenterFloat,
  resource                 =? "Dialog"            -?> doFloat,
  className                =? "gnome-font-viewer" -?> doCenterFloat,
  className                =? "File-roller"       -?> doCenterFloat,
  className                =? "Display"           -?> doCenterFloat,
  className                =? "Artha"             -?> doCenterFloat,
  className                =? "Emacs"             -?> doShift "emacs",
  className                =? "Firefox"           -?> doShift "web",
  className                =? "Google-chrome"     -?> doShift "web"
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

main = do
  -- Earlier this was in executed in startup hook,
  -- unfortunately that seems to break workspace icons
  -- in gnome panel
  spawn "~/.xmonad/startup-hook"
  xmonad $ withUrgencyHook LibNotifyUrgencyHook $ gnomeConfig {
    modMask    = myModMask,
    terminal   = myTerminal,
    workspaces = myWorkspaces,
    layoutHook = myLayouts,
    manageHook = myManagementHooks <+> manageHook gnomeConfig <+> manageDocks
    } `additionalKeys` myKeys `additionalMouseBindings` myMouseBindings
