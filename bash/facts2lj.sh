#!/bin/bash
#
# Entry point for facts2lj scripts.
# Called by F.A.C.T.S. via pipe.
#
# Check input for what type of printout and source the appropriate script
# for output to printer ($0 is link for printer queue), with option
# to save to REPORTS directory for archiving.
#
export myName="facts2lj"
export myVersion="0.3"
export dirBase="/facts"
export dirScripts="${dirBase}/bash"
echo "${myName} ${myVersion} starting initial run" >&2
echo "Sourcing ${dirScripts}/facts2functions.sh" >&2
source ${dirScripts}/facts2functions.sh
#==================================================
# Save report to temp file
fileTmp="$( mktemp ${dirTemp}/${myName}.XXXXXX )"
dbg ${dbg_BASIC} "Saving report as temp file ${fileTmp}"
cat - >"${fileTmp}" || {
    dbg ${dbg_ERROR} "FATAL: Cannot create ${fileTmp}!!!! System full?"
    dbg ${dbg_ERROR} "Exiting"
    exit 1
}
