#!/usr/bin/bash

set -e

errf() { printf "$@\n" >&2; exit 1; }

(( EUID == 0 )) || errf "need root priviledge"

case "$1" in
    ab)
        srcname=a
        dstname=b
        ;;
    ba)
        srcname=b
        dstname=a
        ;;
    *)
        errf "Usage: $(basename $0) <ab|ba>"
        ;;
esac

dstvol_alert="Abort: you are running under '@${dstname}' subvolume now"
findmnt /${srcname} &>/dev/null && errf "$dstvol_alert"
findmnt /${dstname} &>/dev/null || errf "$dstvol_alert"

printf "==> Copy vmlinuz and initrd from '@${srcname}' to '@${dstname}'\n"
stubsrc=/efi/${srcname}
stubdst=/efi/${dstname}
stubtmp=/efi/t
[[ -d $stubdst ]] && mv $stubdst $stubtmp
[[ -d $stubsrc ]] && cp -r $stubsrc $stubdst
[[ -d $stubtmp ]] && rm -rf $stubtmp

dstvol=/${dstname}/@

# remove the read-only protection just in case
[[ -d $dstvol ]] && btrfs prop set -f -ts $dstvol ro false

printf "==> "
[[ -d $dstvol ]] && btrfs subvolume delete $dstvol

printf "==> "
btrfs subvolume snapshot / $dstvol

printf "==> Modify fstab in '/${dstname}/@'\n"
sed -i -r \
    -e "s#/${dstname}#/${srcname}#" \
    -e "s#@${dstname}\s+0#@${srcname}   0#" \
    -e "s#@${srcname}/@#@${dstname}/@#" \
    ${dstvol}/etc/fstab

time=$(date +%Y%m%d.%H%M%S)
timetxt=/${dstname}/timestamp.${time}.txt
rm /${dstname}/*.txt
printf "${time}\n" > $timetxt
printf "==> Create ${timetxt}\n"

