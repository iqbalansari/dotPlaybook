#!/usr/bin/env bash
# Modified version of  Gnome Terminal color scheme install script by Chris Kempson (http://chriskempson.com)

exists () {
    which $1 1> /dev/null 2>&1
}

dset() {
    local key="$1"; shift
    local val="$1"; shift

    if [[ "$type" == "string" ]]; then
        val="'$val'"
    fi

    dconf write "$key" "$val"
}

# because dconf still doesn't have "append"
dlist_append() {
    local key="$1"; shift
    local val="$1"; shift

    local entries="$(
        {
            dconf read "$key" | tr -d '[]' | tr , "\n" | fgrep -v "$val"
            echo "'$val'"
        } | head -c-1 | tr "\n" ,
    )"

    dconf write "$key" "[$entries]"
}

dconf_resolve_default_profile () {
    dconf read /org/gnome/terminal/legacy/profiles:/default | tr -d \'
}

dconf_dump_profile () {
    local profile_slug="$1"

    if test "$profile_slug" = "default" ; then
        local profile_slug=$(dconf_resolve_default_profile)
    fi

    dconf dump "/org/gnome/terminal/legacy/profiles:/:$profile_slug/"
}

gsettings_dump_profile () {
    gsettings list-recursively org.gnome.Terminal.Legacy.Profile:/ \
        | sed 's/^org.gnome.Terminal.Legacy.Profile //g' \
        | awk '{ s = ""; for (i = 2; i <= NF; i++) s = s $i " "; print $1 "=" s }' \
        | paste -s -d'\n' <(echo '[/]') -
}

dconf_profile_exists () {
    dconf list /org/gnome/terminal/legacy/profiles:/ | grep -q "$1"
}

dump_default_profile () {
    if dconf_profile_exists "default" ; then
        dconf_dump_profile default

    else
        gsettings_dump_profile

    fi
}

main () {
    exists dconf || (echo "Please install dconf" && exit 1);

    local profile_name="Base 16 Tomorrow Dark"
    local profile_id=62f4ee90-5743-478c-af66-c64366b4a452

    local dconf_profile_key="/org/gnome/terminal/legacy/profiles:/:$profile_id"

    if ! dconf_profile_exists "$profile_id" ; then
        # Copy all values from existing default profile
        dump_default_profile | dconf load "$dconf_profile_key/"

        # add new copy to list of profiles
        dlist_append '/org/gnome/terminal/legacy/profiles:/list' "$profile_id"
    fi

    # update profile values with theme options
    dset "$dconf_profile_key/visible-name" "'$profile_name'"
    dset "$dconf_profile_key/palette" "['#1d1f21', '#cc6666', '#b5bd68', '#f0c674', '#81a2be', '#b294bb', '#8abeb7', '#c5c8c6', '#969896', '#cc6666', '#b5bd68', '#f0c674', '#81a2be', '#b294bb', '#8abeb7', '#ffffff']"
    dset "$dconf_profile_key/background-color" "'#1d1f21'"
    dset "$dconf_profile_key/foreground-color" "'#c5c8c6'"
    dset "$dconf_profile_key/bold-color" "'#c5c8c6'"
    dset "$dconf_profile_key/bold-color-same-as-fg" "true"
    dset "$dconf_profile_key/use-theme-colors" "false"
    dset "$dconf_profile_key/use-theme-background" "false"
}

main
