#!/bin/sh

# NOTE: bash C-strings (NUL-terminated) internally and so the NULs within the returned subshell text, delineating the file names, will be automatically stripped out (even if left in by `sed`)
#   ... so, just assume files have neither NUL or LF (no-LF might not be a good assumption) within the filename

# spell-checker:ignore shellcheck xargs hexdump printf esac
# spell-checker:ignore NULs subshell repo WGPG Wopenssl senc'd
# spell-checker:words unencrypted

# disable shellcheck "direct is unknown" warnings for the entire script, allowing comments on shellcheck directive lines
# shellcheck disable=SC1107
true

# file "types" (according to `file`) of committed repo files
file_types="$(git ls-files | xargs -r file -0 | hexdump -ve '/1 "%_c"')"

# # empty files
# # shellcheck disable=SC2059 ## note: $file_types is encoded; printf is used here to decode it
# empty_files="$(printf -- "$file_types" |
#     grep --text -aiE "empty" |
#     sed 's/\x0.*$//')"
# for file in $empty_files; do
#     echo "WARN: \"$file\" is empty";
# done

# missing files
# shellcheck disable=SC2059 ## note: $file_types is encoded; printf is used here to decode it
missing_files="$(printf -- "$file_types" |
    grep --text -aiE "cannot open.*?no such file" |
    sed 's/\x0.*$//')"
for file in $missing_files; do
    echo "WARN: \"$file\" is missing";
done

# unencrypted files
# shellcheck disable=SC2059 ## note: $file_types is encoded; printf is used here to decode it
unencrypted_files="$(printf -- "$file_types" |
    grep --text --invert-match -aiE "empty" |
    grep --text --invert-match -aiE "cannot open.*?no such file" |
    grep --text --invert-match -aiE "\WGPG\s.*?encrypted\sdata\W" |
    grep --text --invert-match -aiE "\Wopenssl\senc'd\W" |
    sed 's/\x0.*$//')"

# unencrypted GPG-type or OpenSSL-type files
for file in $unencrypted_files; do
    case $file in
        *.gpg|*.ssl)
            echo "ERR!: \"$file\" is NOT encrypted";
        ;;
    esac
done

# non-"allowed" unencrypted files
non_allowed_files="$(git ls-files "$unencrypted_files" --exclude-standard --ignore)"
for file in $non_allowed_files; do
    echo "ERR!: \"$file\" is NOT encrypted";
done
