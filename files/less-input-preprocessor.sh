#!/bin/sh
exists () {
    which "$1" &> /dev/null ;
}

is_binary () {
    file --brief --mime "$1" | cut -d\; -f1 | grep -q '^application/\(x-executable\|octet-stream\|x-mach-binary\)$'
}

is_text () {
    file --brief --mime "$1" | cut -d\; -f1 | grep -q '^text/'
}

is_media () {
    file --brief --mime "$1" | cut -d\; -f1 | grep -q '^\(video\|audio\)/'
}

is_small_enough () {
    test $(du -k "$filename" | cut -f1) -lt 1048576
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

filename="$1"

# Delegate to lesspipe of the name contains ':'
if test "${filename#*:}" != "$filename" ; then
    lesspipe.sh "$filename" 2> /dev/null

elif [ -f "$filename" ] ; then
    if (is_text "$filename") && (is_small_enough "$filename") ; then
        (pygmentize "$filename" || lesspipe.sh "$filename") 2> /dev/null

    elif is_media "$filename" ; then
        (which ffprobe > /dev/null && ffprobe -hide_banner -i "$filename" 2>&1 | grep -v '^Unsupported codec with' || lesspipe.sh "$filename") 2> /dev/null

    elif is_binary "$filename" ; then
        case "$(uname)" in
            Linux)
                (objdump -d "$filename" || readelf -a "$filename") 2>/dev/null
                ;;
            Darwin)
                otool -vt "$filename"
                ;;
            *)
                exit 1
                ;;
        esac
    else
        lesspipe.sh "$filename" 2>/dev/null
    fi

elif [ -d "$filename" ] ; then
    (tree -L 5 "$filename" || lesspipe.sh "$filename") 2>/dev/null
fi
