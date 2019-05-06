#!/bin/sh

# NOTE: bash C-strings (NUL-terminated) internally and so the NULs within the returned subshell text, delineating the file names, will be automatically stripped out (even if left in by `sed`)
#   ... so, just assume files have neither NUL or LF (no-LF might not be a good assumption) within the filename

# file "types" (according to `file`) of committed repo files
file_types="$(git ls-files | xargs -r file -0 | hexdump -ve '/1 "%_c"')"

# # empty files
# empty_files="$(printf -- "$file_types" |
#     grep --text -aiE "empty" |
#     sed 's/\x0.*$//')"
# for file in $empty_files; do
#     echo "WARN: \"$file\" is empty";
# done

# missing files
missing_files="$(printf -- "$file_types" |
    grep --text -aiE "cannot open.*?no such file" |
    sed 's/\x0.*$//')"
for file in $missing_files; do
    echo "WARN: \"$file\" is missing";
done

# unencrypted files
unencrypted_files="$(printf -- "$file_types" |
    grep --text --invert-match -aiE "empty" |
    grep --text --invert-match -aiE "cannot open.*?no such file" |
    grep --text --invert-match -aiE "GPG.*?encrypted\sdata" |
    sed 's/\x0.*$//')"

# unencrypted GPG-type files
for file in $unencrypted_files; do
    case $file in
        *.gpg)
            echo "ERR!: \"$file\" is NOT encrypted";
        ;;
    esac
done

# non-"allowed" unencrypted files
non_allowed_files="$(git ls-files $unencrypted_files --exclude-standard --ignore)"
for file in $non_allowed_files; do
    echo "ERR!: \"$file\" is NOT encrypted";
done
