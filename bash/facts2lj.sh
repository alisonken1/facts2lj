#!/bin/bash
#
#
# Entry point for facts2lj scripts.
# Called by F.A.C.T.S. via pipe.
#
# Check input for what type of printout and source the appropriate script
# for output to printer ($0 is link for printer queue), with option
# to save to REPORTS directory for archiving.
#
export __name__="facts2lj"
export __version__="0.3"
#
# Set these two so we know where the rest of the scripts are
export dirBase="/facts"
export dirScripts="${dirBase}/bash"
echo "${myName} ${myVersion} starting initial run" >&2
echo "Sourcing ${dirScripts}/facts2functions.sh" >&2
source ${dirScripts}/facts2functions.sh
# At this point the rest of the functions and variables should be useable
#
#==================================================
# Save report to temp file

fileTmp="$( mktemp ${dirTemp}/${myName}.XXXXXX )"
zz=$?
if [ ${zz} -ne 0 ]; then
    dbg ${dbg_FATAL} "Cannot create temporary file!!!! Inodes full?"
    dbg ${dbg_FATAL} "Exiting"
    exit ${zz}
fi
dbg ${dbg_INFO} "Saving to ${fileTmp}"
cat - >"${fileTmp}"
zz=$?
[ ${zz} -ne 0 ] && {
        dbg ${dbg_FATAL} "Cannot create ${fileTmp}!!!! System full?"
        dbg ${dbg_FATAL} "Exiting"
        exit ${zz}
}

# =================================================
# Check for output destination
case ${lpPrinter} in
archive)
    dbg ${dbg_INFO} "Sending data to archive"
    source ${dirScripts}/facts2archive.sh
    ;;
*)
    dbg ${dbg_ERROR} "Unkonwn destination: ${lpPrinter}"
    ;;
esac

rmTmpFiles
