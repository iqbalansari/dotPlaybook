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

myWorkspaces = ["emacs", "shell", "web", "chat", "vm"] ++ map show [6..9]

myKeys = [
  -- Switching / moving windows to workspace
  ((myModMask,               xK_Right), nextWS),
  ((myModMask,               xK_Left), prevWS),
  ((myModMask .|. shiftMask, xK_Right), shiftToNext >> nextWS),
  ((myModMask .|. shiftMask, xK_Left), shiftToPrev >> prevWS),
  ((myModMask,               xK_z), toggleWS),
  
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


myLayouts = smartBorders(avoidStruts(
                            ResizableTall 1 (3/100) (1/2) []
                            ||| Mirror (ResizableTall 1 (3/100) (1/2) [])
                            ||| Grid
                            )
                        )

myManagementHooks :: ManageHook
myManagementHooks = composeAll [
   -- The google hangouts extension
   className =? "crx_nckgahadagoaajjgafhacjanaoiihapd" --> doShift "chat",
   className =? "Emacs"                                --> doShift "emacs",
   className =? "Firefox"                              --> doShift "web",
   className =? "Google-chrome"                        --> doShift "web",
   className =? "Gnome-terminal"                       --> doShift "shell",
   className =? "qemu-system-x86_64"                   --> doShift "vm",
   className =? "qemu-system-x86_64"                   --> doCenterFloat
  ]

main = xmonad $ gnomeConfig {
   modMask    = myModMask,
   terminal   = "gnome-terminal",
   workspaces = myWorkspaces,
   layoutHook = myLayouts,
   manageHook = myManagementHooks <+> manageHook gnomeConfig
  } `additionalKeys` myKeys `additionalMouseBindings` myMouseBindings
