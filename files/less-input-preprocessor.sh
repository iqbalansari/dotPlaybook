#!/bin/sh
exists () {
    which "$1" &> /dev/null ;
}

is_binary () {
    file --brief --mime "$1" | cut -d\; -f1 | grep -q '^application/\(x-executable\|octet-stream\|x-mach-binary\)$'
}

## https://stackoverflow.com/a/3352015/5285712
trim() {
    local var="$*"
    # remove leading whitespace characters
    var="${var#"${var%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    var="${var%"${var##*[![:space:]]}"}"
    echo "$var"
}

lesspipe_compatible () {
    local raw_extensions="a arj tar bz2 bz bz2 deb udeb doc gif jpeg jpg pcd png
                          tga tiff tif iso bin raw lha lzh tar.lz tlz lz tar.lzma
                          lzma pdf rar r[0-9][0-9] rpm tar.gz tgz tar.z tar.dz gz
                          z dz tar jar war ear xpi zip 7z zoo"
    local extensions=$(trim "$(echo $raw_extensions | tr '\n' ' ')")
    local regex="^[^.]*\.\\($(echo $extensions | sed 's/ /\\|/g')\\)$"

    echo "$1" | grep -q -i "$regex"
}

filename="$1"

if [ -f "$filename" ] ; then
    if lesspipe_compatible filename ; then
        lesspipe.sh "$filename"
    else
        if is_binary "$filename" ; then
            case "$system" in
                Linux)
                    objdump -d "$filename" 2> /dev/null || readelf -a "$filename" 2>/dev/null
                    ;;
                Darwin)
                    nm -g "$filename"
                    ;;
                *)
                    exit 1
                    ;;
            esac

        elif [[ $(du -k "$filename" | cut -f1) -lt 1048576 ]] ; then
            source-highlight -i "$filename" -f esc 2> /dev/null || pygmentize 2> /dev/null "$filename"
        fi
    fi
fi
