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

import qualified XMonad.Actions.FlexibleResize as Flex

myModMask = mod4Mask

myTerminal = "gnome-terminal"

myWorkspaces = ["shell", "emacs", "web", "chat", "vm"] ++ map show [6..9]

myKeys = [
  -- Switching / moving windows to workspace
  ((myModMask,               xK_Right), nextWS),
  ((myModMask,               xK_Left), prevWS),
  ((myModMask .|. shiftMask, xK_Right), shiftToNext >> nextWS),
  ((myModMask .|. shiftMask, xK_Left), shiftToPrev >> prevWS),
  ((myModMask,               xK_z), toggleWS),

  -- Use alt + ctrl + t to launch terminal
  ((mod1Mask .|. controlMask, xK_t), spawn myTerminal),
  
  -- Going to a window by title
  ((myModMask,              xK_s), windowPromptGoto defaultXPConfig { autoComplete = Just 500000 } )
  ]
  ++
  -- Use windows + shift + alt + number shift window to workspace numberth workspace and
  -- switch to workspace, similar to windows + shift + right/left
  [((myModMask .|. shiftMask .|. mod1Mask, k), (windows $ W.shift i) >> (windows $ W.greedyView i))
   | (i, k) <- zip myWorkspaces [xK_1 .. xK_9]]

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
  stringProperty "WM_NAME" =? "Hangouts"        -?> doShift "chat",
  resource                 =? "file_properties" -?> doCenterFloat,
  resource                 =? "Dialog"          -?> doFloat,
  className                =? "Emacs"           -?> doShift "emacs",
  className                =? "Firefox"         -?> doShift "web",
  className                =? "Google-chrome"   -?> doShift "web"
   ] <+> composeAll [
    className =? "qemu-system-x86_64" --> doShift "vm",
    className =? "qemu-system-x86_64" --> doCenterFloat
   ]

main = do
  -- Earlier this was in executed in startup hook,
  -- unfortunately that seems to break workspace icons
  -- in gnome panel
  spawn "~/.xmonad/startup-hook"
  xmonad $ gnomeConfig {
    modMask    = myModMask,
    terminal   = myTerminal,
    workspaces = myWorkspaces,
    layoutHook = myLayouts,
    manageHook = myManagementHooks <+> manageHook gnomeConfig <+> manageDocks
    } `additionalKeys` myKeys `additionalMouseBindings` myMouseBindings
