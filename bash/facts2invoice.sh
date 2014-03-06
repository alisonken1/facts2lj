# DO NOT RUN THIS BY ITSELF
# It is designed to be sourced by originating file
#
# Convert FACTS invoice output for Abletronics to Postscript
#
__name__="facts2invoice"
__version__="0.2"
__release__="BETA"

if [ "${__status__}" != "RUN" ]; then
    echo ${__name__} ${__version__} ${__release__}
else
    #
    # Convert F.A.C.T.S. invoice output (plain text) formatted for preprinted
    # Abletronics forms to postscript
    #
    # =======================================================================
    #
    # WARNING: Script written for bash v3.1. May work on other versions.
    #          One-off script written for Slackware 12.0 bash
    #
    # NOTE: Process substitution allows for loops (while .. do .. done) to modify
    #       variables outside of the loop.
    #       To process do .. done loops, use the following template:
    #         while ... ; do
    #           ...
    #         done < <(...)
    #
    # NOTE: FD's are used to redirect several outputs used by this script.
    #       Change $$ to ${invInfo_NUMBER} after run to keep track of stuff
    #       until testing done.
    #       Directory/file defines:
    #         dirBase="/facts"
    #         dirTmp="${dirBase}/tmp"
    #         filePre="${dirTmp}/invoice_"
    #         filePS="${filePre}$$.ps"
    #         fileTmp="{filePre}$$.tmp"
    #         fileItems="${filePre}$$.items"
    #         fileWork="${filePre}$$.work
    #
    #         fdError=2
    #         fdItem=3
    #         fdInput=7
    #         fdLoop=8
    #         dMain=9
    #
    #       FD 0,1,2 : normal use
    #       FD 3     : "${fileItems}" while building data
    #                : Used to isolate line items on first pass
    #       FD 7     : "${dirTmp}/${filePre}out.txt"
    #                : Unmodified input lines being processed
    #       FD 8     : ${tmpWork}/invoice_work.txt
    #                : Input lines with blank lines removed
    #       FD 9     : 9<&1
    #                :
    #
    # NOTE: Section line counts: (ignored as of v0.2)
    #       HEADER : 01 - 20
    #       ITEMS  : 21 - 56
    #       FOOTER : 57 - 63
    #
    # NOTE: Changelog
    #       2013-09-06 : Fixed phone number oops
    #       2013-08-30 : Added check for print ticket - set printer options
    #                  : so print ticket doesn't overrun the page
    #       2013-08-30 : Moved printing to printme() since we need to call
    #                  : printing from several areas and added
    #                  : ${lprOpts}
    #       2013-08-30 : Check for pgEOF being set by getNext()
    #       2013-08-28 : Added rmTmpfiles() since we have several exit points
    #       2013-08-16 : Fixed item processing loop for multi-page invoice
    #       2013-08-08 : Fixed oops in summary where bill/ship info was being
    #                  : sent via 'echo ...' rather than 'dbg ....'
    #       2013-08-08 : Fixed oops in print routine where printout was going
    #                  : to default printer rather than specified printer
    #       2013-08-08 : Fixed oops in getNext() with difference in ${z^^} not
    #                  : useable in older version of bash
    #       2013-08-07 : Changed lprPrinter variable to use basename ${0}
    #                  : as printer to send to
    #       2013-08-07 : Added stripme() to ensure leading/trailing whitespace
    #                  : characters are removed
    #       2013-08-07 : Changed item loop to account for different parts of
    #                  : FACTS sending item lines of different lengths
    #       2013-08-07 : Refactored header/items/footer parsing to more
    #                  : closely follow FACTS output
    #       2013-08-05 : Renamed to facts2lj.sh
    #       2013-07-31 : Relocated some variables higher in the script
    #       2013-07-24 : Fixed dropping first 2 characters in description
    #       2013-07-22 : Fixed footer parsing
    #       2013-07-02 : Initial testing on server
    #       2013-04-08 : Basic script
    #
    # =================== Variables Used ======================================
    #
    # ==================
    # Directory defines
    # ==================
    export dirBase="/facts"
    export dirScripts="${dirBase}/bash"
    . ${dirScripts}/facts2functions.sh
    #
    # ==================
    # File descriptor variables
    # ==================
    export fdError=2
    export fdItem=3
    export fdInput=7
    export fdLoop=8
    export fdMain=9
    #
    # ==================
    # File variables
    # ==================
    export filePre="${dirTmp}/invoice_"
    export fileNumber="$$"
    export fileWork="$( getTempFile ${filePre}${fileNumber} ).work"
    # export filePS="${filePre}$$.ps" # Define later when inv# known
    # export fileItems="${filePre}$$.items" # Define later when inv# known
    #
    # ==================
    # FACTS direct invoice entry variables
    # ==================
    export pgPICK=0 # Keep track of pick ticket
    export pgHEAD=0 # Keep track of processed header
    export pgFOOT=0 # Keep track of processed footer
    export pgEOF=0  # Keep track of processed invoice
    export pgItem=0 # Keep track of invItems_OFFSET checked or not
    #
    # Number of lines in each section
    export invHeadEnd=20
    export invItemEnd=37
    export invFootEnd=5
    # Including /n character at end of line
    export invLines_HEAD=81  # Length of header lines (not used?)
    export invLines_ITEM=135 # Length of item lines
    export invLines_FOOT=136 # Length of footer lines (not used?)
    #
    # ==================
    # Postscript page defines
    # ==================
    export xmin=15
    export ymin=10
    export xmax=595
    export ymax=792
    export invInfo_ITEMSPAGEMAX=41 # Used for PS output number of items/page
    #
    # ==================
    # Abletronics adx info
    # ==================
    export adxAble_NAME="AbleTronics"
    export adxAble_TAG="Electronics Components and Supplies"
    export adxAble_STREET="9860 6th Street"
    export adxAble_CITY="Rancho Cucamonga"
    export adxAble_STATE="CA"
    export adxAble_ZIP="91730"
    export adxAble_PHONE="(909) 987-7606"
    export adxAble_FAX="(909) 945-9449"
    export adxAble_WEB="http://www.abletronics.com"
    #
    # ==================
    # Invoice header information
    # ==================
    # Invoice data after processing
    export invInfo_DATE=''
    export invInfo_FREIGHT=''
    export invInfo_ITEMSPAGE=${invInfo_ITEMSPAGEMAX}
    export invInfo_NUMBER=''
    export invInfo_PO=''
    export invInfo_SALES=''
    export invInfo_SHIPDATE=''
    export invInfo_SHIPTYPE=''
    export invInfo_SUBTOTAL=''
    export invInfo_TAX=''
    export invInfo_TERMS=''
    export invInfo_TOTAL=''
    export invInfo_PAGES=0 # Total pages to print per invoice
    export invInfo_ITEMS=0 # Total items processed
    #
    # ==================
    # Invoice item information
    # ==================
    # Processed item info - we don't do any math so just keep as strings
    export invItems_BACK=''         # Number of Items backordered
    export invItems_DESCRIPTION=''  # Item description
    export invItems_ITEM=''         # Abletronics item number
    export invItems_ORDER=''        # Number of Items originally ordered
    export ivnItems_PRICETOT''      # [SHIPPED] * [PRICEUI]
    export invItems_PRICEUI=''      # Unit price of item
    export invItems_SHIPED=''       # Number of Items actually shipped
    export invItems_VENDOR=''       # Item vendor (vendor ID + vendor part)
    export invItems_OFFSET=0        # Used to check for pick ticket invoice
    export invItems_Count=0         # Keep track of number of items we found
    #
    # ==================
    # Invoice variables used in script
    # ==================
    # Use an array for header information so we can make sure we process
    # the proper data
    # invHead[0] = Invoice date | Invoice number
    # invHead[1] = Account number
    # invHead[2+] = Address
    # invHead[-1] = PO | Salesperson | Freight | Origin Date | Terms
    declare -ax  invHead # Raw header with blank lines removed
    # Billing/shipping info
    # [0]  = account
    # [1+] = address
    declare -ax invBill
    declare -ax invShip
    # Memo fields from footer
    declare -ax invMemo
    #
    # ==================
    # Debug variables
    # ==================
    export dbg_NONE=0
    export dbg_ERROR=$(( ${dbg_NONE} + 1 ))
    export dbg_BASIC=$(( ${dbg_ERROR} +1 ))
    export dbg_SUB=$(( ${dbg_BASIC} + 1 ))
    export dbg_LOOP=$(( ${dbg_SUB} + 1 ))
    export dbg_DATA=$(( ${dbg_LOOP} + 1 ))
    export dbg_VAR=$(( ${dbg_DATA} + 1 ))
    export dbg_ALL=99
    export dbgLevel=${dbg_ALL}
    #
    # ===================== Local Functions ====================================
    dbg() {
      # $1 = debug level for output
      # $2 $N = line to print
      local dbgz dbglvl zz
      dbglvl=${1} ; shift
      [ ${dbglvl} -eq ${dbg_NONE} ] && return
      [ ${dbglvl} -gt ${dbgLevel} ] && return
      zz=${@}
      case ${dbglvl} in
      ${dbg_DATA} | ${dbg_VAR} )
        # Indent input line
        echo "     ${zz}" >&2
        ;;
      * )
        # Just dump line
        echo "${zz}" >&2
        ;;
      esac
    } # dbg()
    # ===================
    getNext () {
      # Read the next line of input
      # Return ${string} on stdout, Return ${?} of read status
      # Strips only \f\n\r out of string
      dbg ${dbg_SUB} "getNext() 1=${1} 2=${2} called"
      local gnzz gnss gndt IFS gnskip gncount gnread
      IFS="/f/n/r"
      if [ "${1::5}" == "BLANK" ] ; then
        gnskip=1 # Skip $2 number of lines
      elif [ "${1::4}" == "SKIP" ] ; then
        gnskip=2 # Skip only blank lines
      else
        gnskip=0
      fi # ${1} checks
      # Use the largest section as the maximum count if skipping lines
      # and no number given
      gncount=${2:-$invItemEnd}
      dbg ${dbg_VAR} "gnskip=${gnskip} gncount=${gncount}"
      gnread=0
      for (( i=1; i<=${gncount}; i++ )) ; do
        read gnzz
        gnss=$?
        echo "${gnzz}">&7
        case ${gnss} in

          0)
            # Good read
            dbg ${dbg_LOOP} "READ: ${gnzz}"
            ;;
          1)
            # EOF
            dbg ${dbg_LOOP} "READ: EOF detected"
            export pgEOF=1
            gnread=${gncount}
            break
            ;;
          *)
            # Error
            dbg ${dbg_ERROR} "READ: ERROR CODE ${ss} - Exiting"
            exit
            ;;
        esac
        if [ ${gnskip} -eq 0 ] ; then
          dbg ${dbg_LOOP} "getNext() returning 1 line"
          break # Read one line only
        elif [ ${gnskip} -eq 1 ] ; then
          zz=$(echo ${gnzz})
          [ ${#zz} -gt 2 ] && break # Return on first non-blank line
        fi # ${gnskip} -eq 1
        gnread=$(( ${gnread} + 1 ))
      done
      echo -n "${gnzz}" | tr -d '\f\n\r'  # Return line to caller on stdout
      return ${gnread}  # Exit with number of lines read
    } # getNext()
    # ===================
    stripme () {
      # Echo back what's sent stripping extra spaces/\n/\r/\f characters
      echo -ne ${@}
    } # stripme()
    # ===================
    rmTmpfiles () {
      dbg ${dbg_SUB} "rmTmpfiles() called"
      # Remove temporary files before exiting
      dbg ${dbg_BASIC} "Cleaning temporary files ${filePS} ${fileItems} ${fileWork} ${fileTest}"
      rm ${filePS} ${fileItems} ${fileWork} ${fileTest} >/dev/null 2>&1
    }
    # ===================
    printMe () {
      # ${1} is the file to print
      dbg ${dbg_SUB} "printMe() called"
      dbg ${dbg_BASIC} "Finished PS conversion run - sending ${1} to printer ${lprPrinter}"
      dbg ${dbg_BASIC} "Print command: '${lprCommand} -P ${lprPrinter} ${lprOpts} ${1}'"
      ${lprCommand} -P ${lprPrinter} ${lprOpts} ${1}
      sleep 3
      return
    }
    # ===================
    #
    # =================== Main Script ========================================
    #
    dbg ${dbg_ERROR} "Starting invoice conversion run facts2lj.sh version ${VERSION}"
    #
    dbg ${dbg_SUB} "Cleaning up any previous temp files"
    rmTmpfiles
    #
    dbg ${dbg_SUB} "Opening FD's for redirection"
    exec 3>"${fileItems}"
    exec 7>"${fileTest}"
    exec 9<&1
    #
    dbg ${dbg_BASIC} "Saving input to ${fileWork}"
    cat - >${fileWork}
    dbg ${dbg_LOOP} "Starting initial invoice conversion"
    # A little convoluted pulling in from stdin due to trying to use
    # debug statements to figure out how the invoices/pick tickets are
    # actually sent from FACTS
    while [ ${pgEOF} -eq 0 ] ; do
      #
      export pgEOF
      nextLine="$( getNext BLANK ${invHeadEnd} )"
      zzchk=$?
      # Check for pgEOF being set by getNext
      [ ${pgEOF} -ne 0 ] && {
        dbg ${dbg_LOOP} "End of input - breaking out"
        continue
      }
      [ "${nextLine:5:15}" == "===============" ] && {
        # Pick ticket
        export lprOpts="${lprOpts} -o media=Letter -o page-left=28"
        export lprOpts="${lprOpts} -o cpi=12 -o lpi=6 -o page-top=36"
        printMe ${fileWork}
        exit
      }
      # Check if blank header - end of invoice
      dbg ${dbg_VAR} "getNext() returned status ${zzchk}"
      [ ${zzchk} -gt 10 ] && {
        export pgEOF=1
        dbg ${dbg_LOOP} "Blank header - setting pgEOF=${pgEOF}"
        continue
      }
      #
      if [ ${pgHEAD} -ne 0 ] ; then
        dbg ${dbg_LOOP} "Skipping multipage header"
        nextLine=$( getNext BLANK ${invHeadEnd} )
        nextLine=$( getNext SKIP 5 ) # account/address lines
        nextLine=$( getNext BLANK ${invHeadEnd} )
        nextLine=$( getNext SKIP 1 ) # PO/.../terms line
      else
        dbg ${dbg_LOOP} "Processing header"
        invInfo_DATE=$( stripme ${nextLine::66} )
        dbg ${dbg_VAR} "Setting invoice DATE to ${invInfo_DATE}"
        invInfo_NUMBER=$( stripme ${nextLine:67} )
        dbg ${dbg_VAR} "Setting invoice NUMBER to ${invInfo_NUMBER}"
        #
        nextLine="$( getNext BLANK ${invHeadEnd} )"
        zz=$(stripme ${nextLine::40} )
        [ ${#zz} -ge 2 ] && {
          invBill[0]=${zz}
          dbg ${dbg_VAR} "Setting BILLTO account to ${invBill[0]}"
        }
        zz=$( stripme ${nextLine:40:30} )
        [ ${#zz} -ge 2 ] && {
          invShip[0]=${zz}
          dbg ${dbg_VAR} "Setting SHIPTO account to ${invShip[0]}"
        }
        #
        dbg ${dbg_LOOP} "Getting invoice billing/shipping addresses"
        for (( i=1; i<=4; i++ )) ; do
          nextLine="$( getNext )"
          zz=$(stripme ${nextLine::40} )
          [ ${#zz} -gt 2 ] && {
            invBill[${i}]=${zz}
            dbg ${dbg_VAR} "Adding BILLTO address ${invBill[$i]}"
          }
          zz=$( stripme ${nextLine:40} )
          [ ${#zz} -gt 2 ] && {
            invShip[${i}]=${zz}
            dbg ${dbg_VAR} "Adding SHIPTO address ${invShip[$i]}"
          }

        done # ${i} <= 4
        dbg ${dbg_VAR} "Getting PO/sales/freight/order date/terms"
        nextLine="$( getNext BLANK ${invHeadEnd} )"
        zz=$(stripme ${nextLine::20} )
        [ ${#zz} -ge 2 ] && invInfo_PO=${zz}
        dbg ${dbg_VAR} "Setting PO to ${invInfo_PO}"
        zz=$( stripme ${nextLine:20:8} )
        [ ${#zz} -ge 2 ] && invInfo_SALES=${zz}
        dbg ${dbg_VAR} "Setting SALES to ${invInfo_SALES}"
        zz=$( stripme ${nextLine:28:16} )
        [ ${#zz} -ge 2 ] && invInfo_SHIPTYPE=${zz}
        dbg ${dbg_VAR} "Setting SHIPTYPE to ${invInfo_SHIPTYPE}"
        zz=$( stripme ${nextLine:52:12} )
        [ ${#zz} -ge 2 ] && invInfo_SHIPDATE=${zz}
        dbg ${dbg_VAR} "Setting SHIPDATE to ${invInfo_SHIPDATE}"
        zz=$( stripme ${nextLine:65} )
        [ ${#zz} -ge 2 ] && invInfo_TERMS=${zz}
        dbg ${dbg_VAR} "Setting TERMS to ${invInfo_TERMS}"
        export pgHEAD=1 # Set notice that header has been processed
      fi # ${pgHead} -ne 0
      #
      dbg ${dbg_LOOP} "Processing items lines ${invItemEnd}"
      while [ ${pgItem} -eq 0 ] ; do
        nextLine="$(getNext BLANK)" # Get the first item
        linesSkipped=$?
        zz=$( stripme ${nextLine} )
        skipLines=$(( ${invItemEnd} - 1 ))
        for (( i=${invItemEnd}; i>0; i-- )) ; do
    #      [ ${#zz} -lt 3 ] && {
    #        dbg ${dbg_LOOP} "Skipping blank line"
    #        break # Assume no more entries after a blank line received
    #      }
          dbg ${dbg_VAR} "Testing pgItem=0 : ${pgItem}"
          [ ${pgItem} -eq 0 ] && {
            # Check for item line length longer than what we expect for proper
            # parsing
            [ ${#nextLine} -gt ${invLines_ITEM} ] && {
              export pgItem=1
              export invItems_OFFSET=$(( ${#nextLine} - ${invLines_ITEM} ))
              dbg ${dbg_LOOP} "Setting item line offset to ${invItems_OFFSET}"
            } # ${#nextLine} -gt ${invLines_ITEM}
          } # ${pgItem} -ne 0
          echo "${nextLine}">&3
          invInfo_ITEMS=$(( ${invInfo_ITEMS} + 1 ))
          dbg ${dbg_LOOP} "Saving item number ${invInfo_ITEMS}"
          nextLine="$( getNext BLANK ${skipLines} )"
          linesSkipped=$(( $? - 1 ))
          zz="$( stripme ${nextLine} )"
          [ "${zz::8}" == "CONTINUE" ] && {
            dbg ${dbg_LOOP} "Skipping CONTINUED line and multipage header"
            newLine="$( getNext SKIP 16 )" # Skip multipage header
            break # No more items on this page
          }
          [ ${linesSkipped} -ge 2 ] && {
            pgItem=1
            break
          }
          skipLines=$(( ${i} - ${linesSkipped} - 1))
          zz="$( stripme ${nextLine} )"
        done # ${i} <= ${invItemEnd
        #
      done # ${pgItem} -eq 0
      if [ ${pgFOOT} -ne 0 ] ; then
        # Already processed, so skip
        dbg ${dbg_LOOP} "Skipping multipage footer"
        nextLine=$( getNext BLANK )
        nextLine=$( getNext SKIP 4 )
      else
        dbg ${dbg_LOOP} "Processing footer"
        #
        # ====== Subtotal ====
    #    nextLine="$( getNext BLANK ${invItemEnd} )" ; pgLine=$(( ${pgLine} + 1 ))
        # Subtotal
        zz=$( stripme ${nextLine::120} )
        [ ${#zz} -ge 2 ] && {
          invMemo[ ${#invMemo[@]} ]=${zz}
          dbg ${dbg_VAR} "Adding memo line ${zz}"
        } # ${zz} -ge 2
        invInfo_SUBTOTAL=$( stripme ${nextLine:120} )
        dbg ${dbg_VAR} "Setting invoice subtotal to ${invInfo_SUBTOTAL}"
        #
        # ====== Freight ======
        nextLine="$( getNext )" ; pgLine=$(( ${pgLine} + 1 ))
        zz=$(stripme ${nextLine::120} )
        [ ${#zz} -ge 2 ] && {
          invMemo[ ${#invMemo[@]} ]=${zz}
          dbg ${dbg_VAR} "Adding memo line ${zz}"
        } # ${zz} -ge 2
        invInfo_FREIGHT=$( stripme ${nextLine:120} )
        dbg ${dbg_VAR} "Setting invoice freight to ${invInfo_FREIGHT}"
        #
        # ===== Tax ======
        nextLine="$( getNext )" ; pgLine=$(( ${pgLine} + 1 ))
        zz=$( stripme ${nextLine::120} )
        [ ${#zz} -ge 2 ] && {
          invMemo[ ${#invMemo[@]} ]=${zz}
          dbg ${dbg_VAR} "Adding memo line ${zz}"
        } # ${zz} -ge 2
        invInfo_TAX=$( stripme ${nextLine:120} )
        dbg ${dbg_VAR} "Setting invoice tax to ${invInfo_TAX}"
        #
        # ====== Blank line ======
        nextLine="$( getNext )" ; pgLine=$(( ${pgLine} + 1 ))
        zz=$( stripme ${nextLine::120} )
        [ ${#zz} -ge 2 ] && {
          invMemo[ ${#invMemo[@]} ]=${zz}
          dbg ${dbg_VAR} "Adding memo line ${zz}"
        } # ${zz} -ge 2
        #
        # ====== Total line ======
        nextLine="$( getNext )" ; pgLine=$(( ${pgLine} + 1 ))
        zz=$( stripme ${nextLine::120} )
        [ ${#zz} -ge 2 ] && {
          invMemo[ ${#invMemo[@]} ]=${zz}
          dbg ${dbg_VAR} "Adding memo line ${zz}"
        } # ${zz} -ge 2
        invInfo_TOTAL=$( stripme ${nextLine:120} )
        dbg ${dbg_VAR} "Setting invoice total to ${invInfo_TOTAL}"
        #
        export pgFOOT=1 # Set notice that footer has been processed
      fi # ${pgFOOT} -ne 0
    # done < <(cat -) # Main loop
    done < <(cat ${fileWork})
    #
    dbg ${dbg_LOOP} "Closing fdMain"
    exec 9<&-
    dbg ${dbg_LOOP} "Closing fdWork"
    exec 7<&-
    dbg ${dbg_LOOP} "Closing fdItems"
    exec 3<&-
    #
    [ -z "$( echo ${invInfo_TOTAL} )" ] && {
      dbg ${dbg_ERROR} "No total cost for inovice - invoice error?"
      rmTmpfiles
      exit 3
    }
    #
    dbg ${dbg_VAR} "Total items processed: ${invInfo_ITEMS}"
    #
    zz=$(( ${invInfo_ITEMS} / ${invInfo_ITEMSPAGEMAX} ))
    if [ $(( ${invInfo_ITEMS} % ${invInfo_ITEMSPAGEMAX} )) -ne 0 ] ; then
      invInfo_PAGES=$(( ${zz} + 1 ))
    else
      invInfo_PAGES=${zz}
    fi
    dbg ${dbg_VAR} "Number of pages per invoice: ${invInfo_PAGES}"
    #
    dbg ${dbg_VAR} "Invoice number       : ${invInfo_NUMBER}"
    dbg ${dbg_VAR} "Invoice date         : ${invInfo_DATE}"
    dbg ${dbg_VAR} "Billing information  : ${invBill[0]}"
    for (( i=1; i<${#invBill[@]}; i++ )) ; do
      dbg ${dbg_VAR} "${invBill[$i]}"
    done
    dbg ${dbg_VAR} "Shipping information : ${invShip[0]}"
    for (( i=1; i<${#invShip[@]}; i++ )) ; do
      dbg ${dbg_VAR} "${invShip[$i]}"
    done
    dbg ${dbg_VAR} "PO Number            : ${invInfo_PO}"
    dbg ${dbg_VAR} "Salesperson          : ${invInfo_SALES}"
    dbg ${dbg_VAR} "Shipping type        : ${invInfo_SHIPTYPE}"
    dbg ${dbg_VAR} "Shipping Date        : ${invInfo_SHIPDATE}"
    dbg ${dbg_VAR} "Payment terms        : ${invInfo_TERMS}"
    #
    # Set the PS filename to the invoice number
    filePS=$( echo "${filePre}${invInfo_NUMBER}.ps" | tr -d ' \n\r\f' )
    dbg ${dbg_BASIC} "Setting postscript output file to  ${filePS}"
    #
    zz=$( echo "${filePre}${invInfo_NUMBER}.items" | tr -d ' \n\r\f' )
    dbg ${dbg_BASIC} "Changing item file name to ${zz}"
    mv ${fileItems} ${zz}
    fileItems=${zz}
    #
    zz=$( echo "${filePre}${invInfo_NUMBER}.work" | tr -d ' \n\r\f' )
    dbg ${dbg_BASIC} "Renaming work file to ${zz}"
    mv ${fileWork} ${zz}
    fileWork=${zz}

    #
    dbg ${dbg_LOOP} "Setting fdMain to output to ${filePS}"
    dbg ${dbg_LOOP} "Resetting fdMain redirection for item listing"
    exec 9<&1
    {
      # Postscript header information
      cat <<HERE
    %!PS-Adobe-3.0 EPSF-3.0
    %%Creator: invoice.sh bash script created by Ken Roberts
    %%Title: Abletronics invoice number ${invInfo_NUMBER}
    %%CreationDate: Thu Jul 12 01:45:30 PDT 2012
    %%DocumentData: Clean7Bit
    %%Origin: 0 0 % ${xmin} ${ymin}
    %%BoundingBox: ${xmin} ${ymin} ${xmax} ${ymax}
    %%LanguageLevel: 2 [could be 1 2 or 3]
    %%Pages: ${invInfo_PAGES}
    %
    % PS version of AbleTronics sales invoice
    %
    % blank box so we can copy/paste for section breaks
    %
    %  =====================================================
    % |                                                     |
    %  =====================================================
    %
    %  =====================================================
    % |           Invoice specific defines                  |
    %  =====================================================
    % Billing info
    /itemsTotal { ${invInfo_ITEMS} } bind def
    /pagesTotal { ${invInfo_PAGES} } bind def
    /billAcct { ( ${invBill[0]} ) } bind def
    /shipAcct { ( ${invShip[0]} ) } bind def
    HERE
      echo -en   '/billAdx {['
      for (( i=1; i<${#invBill[@]}; i++ )) ; do
        echo -en "(${invBill[$i]})"
      done
      echo -en "]} def\n"
      echo '%'
      echo '% Shipping info'
      echo '%'
      echo -en '/shipAdx {['
      for (( i=1; i<${#invShip[@]}; i++ )) ; do
        echo -en "(${invShip[$i]})"
      done
      echo -en "]} bind def\n"
    #
      cPg=1
      cat <<HERE
    %
    % Array of item lines arrays
    /itemList [
    [ % Page ${cPg} array
    $(
      dbg ${dbg_LOOP} "Building itemList array"
      dbg ${dbg_LOOP} "Building PS page ${cPg} array"
      cItm=0
      cLeft=${invInfo_ITEMS}
      ifsR="${IFS}"
      IFS='\n' # Read unprocessed line so we get the correct spacing
      cat "${fileItems}" | while read newLine ; do
        dbg ${dbg_VAR} "newLine: '${newLine}'"
        IFS="${ifsR}"
        # Should be no blank lines, so we can exit here
        [ -z "$( echo ${newLine} )" ] && break
        cItm=$(( ${cItm} + 1 ))
        cLeft=$(( ${cLeft} - 1 ))
        invItems_ORDER="$( echo ${newLine::8} )"
        invItems_SHIPPED="$( echo${newLine:8:14} )"
        invItems_BACK="$( echo ${newLine:22:10} )"
        invItems_ITEM="$( echo ${newLine:32:8} )"
        invItems_VENDOR="$( echo ${newLine:43:26}|sed -e 's/(/\\(/g' -e 's/)/\\)/g' )"
        [ ${invItems_OFFSET} -eq 0 ] && {
          invItems_DESCRIPTION="$( echo  ${newLine:72:36} | sed -e 's/(/\\(/g' -e 's/)/\\)/g' )"
          invItems_PRICEUI="$( echo ${newLine:106:14} )"
          invItems_PRICETOT="$( echo ${newLine:120} )"
        } || {
          # Offset for pick ticket invoices
          invItems_DESCRIPTION="$( echo ${newLine:75:36}|sed -e 's/(/\\(/g' -e 's/)/\\)/g' )"
          invItems_PRICEUI="$( echo ${newLine:109:14} )"
          invItems_PRICETOT="$( echo ${newLine:123} )"
        }
        dbg ${dbg_VAR} "ORDER=${invItems_ORDER}"
        dbg ${dbg_VAR} "SHIPPED=${invItems_SHIPPED}"
        dbg ${dbg_VAR} "BACK=${invItems_BACK}"
        dbg ${dbg_VAR} "ITEM=${invItems_ITEM}"
        dbg ${dbg_VAR} "VENDOR=${invItems_VENDOR}"
        dbg ${dbg_VAR} "DESCRIPTION=${invItems_DESCRIPTION}"
        dbg ${dbg_VAR} "PRICEUI=${invItems_PRICEUI}"
        dbg ${dbg_VAR} "PRICETOT=${invItems_PRICETOT}"
        echo "[(${invItems_ORDER})\
    (${invItems_SHIPPED})\
    (${invItems_BACK})\
    (${invItems_ITEM})\
    (${invItems_VENDOR})\
    (${invItems_DESCRIPTION})\
    (${invItems_PRICEUI})\
    (${invItems_PRICETOT})]"
        if [ ${cItm} -eq ${invInfo_ITEMSPAGE} ] ; then
          if [ ${cLeft} -gt $(( ${invInfo_ITEMSPAGEMAX} - ${invInfo_ITEMSPAGE} )) ] ; then
            cPg=$(( ${cPg} + 1 ))
            dbg ${dbg_LOOP} "Building PS page ${cPg} array"
            echo -ne "]\n[ % Page ${cPg} array\n"
            cItm=0
          fi
        fi
        IFS='\n'
      done
      IFS="${ifsR}"
      dbg ${dbg_LOOP} "Finished building PS page array"
    )
    ]
    ] def
    %
    %  =====================================================
    % |             Basic page layout defines               |
    %  =====================================================
    % Typical page size
    % Folio             595 x 935
    % Letter            612 x 792
    % This is actually between folio and letter in height, but that's based on
    % using Okular from KDE 4.3 on linux - may need to update when we get a printer
    % to play with
    %
    %  =====================================================
    % |               Physical page size                    |
    %  =====================================================
    /paperWidth {595} bind def
    /paperHeight {792} bind def
    %
    %  =====================================================
    % |         Printable area of paper                     |
    %  =====================================================
    % Remember 0,0 is bottom left point
    /marginX {15} bind def
    /marginY {10} bind def
    /pageTop { paperHeight marginY sub } bind def
    /pageBottom { marginY } bind def
    /pageLeft { marginX 5 add } bind def % Just a little extra for mechanics
    /pageRight { paperWidth marginX 2 mul sub } bind def
    /pageWidth { pageRight pageLeft sub} bind def
    /pageHeight {pageTop pageBottom sub} bind def
    /pageX { pageLeft } bind def
    /pageY { marginY } bind def
    %
    %  =====================================================
    % |          Page layout basic areas                    |
    %  =====================================================
    %
    % Radius of curves in boxes
    /boxRadius {10} bind def
    %
    % Store return address box
    /boxStoreW { 270 } bind def
    /boxStoreH { 90 } bind def
    /boxStoreX { pageLeft 20 add } bind def
    /boxStoreY { 687 } bind def
    %
    % Invoice number/date/pages
    /boxInvoiceW { 150 } bind def
    /boxInvoiceH { 90 } bind def
    /boxInvoiceX { 425 } bind def
    /boxInvoiceY { 687 } bind def
    %
    % Bill to address box
    /boxBillW { 205 } bind def
    /boxBillH { 90 } bind def
    /boxBillX { 85 } bind def
    /boxBillY { 582 } bind def
    %
    % Ship to number/date/pages
    /boxShipW { 205 } bind def
    /boxShipH { 90 } bind def
    /boxShipX { 370 } bind def
    /boxShipY { 582 } bind def
    %
    % Sales info box
    /boxSalesW { 560 } bind def
    /boxSalesH { 50 } bind def
    /boxSalesX { 20 } bind def
    /boxSalesY { 522 } bind def
    /boxSalesSecW { 112 } bind def
    /boxSalesPO { 25 } bind def
    /boxSalesPerson { 137 } bind def
    /boxSalesShip { 249 } bind def
    /boxSalesDate { 361 } bind def
    /boxSalesTerms { 473 }bind def
    %
    % Item info box
    % Define the size of the item header box since we use it elsewhere
    /boxItemHeadH { 35 } bind def
    /boxItemW { boxSalesW } bind def
    /boxItemH { 430 boxItemHeadH sub } bind def
    /boxItemX { 20 } bind def
    /boxItemY { 95 } bind def
    /boxItemOrder { 20 } bind def
    /boxItemOrderW { 50 } bind def
    /boxItemShip { 70 } bind def
    /boxItemBack { 120 } bind def
    /boxItemCode { 170 } bind def
    /boxItemCodeW { 50 } bind def
    /boxItemVendor { 220 } bind def
    /boxItemDesc { 345 } bind def
    /boxItemUI { 475 } bind def
    /boxItemExtended { 525 } bind def
    %
    % Item header box - see above for boxItemH
    /boxItemHeadW { boxItemW } bind def
    /boxItemHeadX { boxItemX } bind def
    /boxItemHeadY { boxItemY boxItemH add  } bind def
    %
    % Memo boxes
    /boxMemoW { 336 } bind def
    /boxMemoH { 75 } bind def
    /boxMemoX { 20 } bind def
    /boxMemoY { 22 } bind def
    %
    % Totals box
    /boxTotalW { 224 } bind def
    /boxTotalH { 75 } bind def
    /boxTotalX { 356 } bind def
    /boxTotalY { 22 } bind def
    %
    %  =====================================================
    % |                   Font definitions                  |
    %  =====================================================
    %
    /ptSize {10} bind def % Default to 10 point size
    /fntStoreName {/Courier-New-Bold findfont ptSize 2.50 mul scalefont} def
    /fntStoreBite {/Courier-New-Bold findfont ptSize scalefont} bind def
    /fntStoreAdx {/Times-New-Roman findfont ptSize 1.00 mul scalefont} def
    /fntWaterMark {/Courier-New-Bold findfont 32 scalefont} def
    /fntInvoiceHead {/Courier-New-Bold findfont ptSize 2.0 mul scalefont } def
    /fntInvoiceText {/Courier-New-Bold findfont ptSize scalefont } def
    /fntItemHead {/Courier-New-Bold findfont ptSize 0.80 mul scalefont } def
    /fntInvoiceItem {/Courier-New-Bold findfont ptSize 0.70 mul scalefont } def
    %
    %  =====================================================
    % |          Location for return address                |
    %  =====================================================
    /adxAbleX { 25 } bind def
    /adxAbleY { 772 } bind def
    %
    %  =====================================================
    % |                 Debugging Routines                  |
    %  =====================================================
    %
    % For testing, use the bottom of the page for status checks
    % Used for testing with interactive interpreter like gs
    %
    % Clears the status box
    /clearStatus
    {
      gsave
      1.0 setgray
      0 0 paperWidth 45 rectfill
      grestore
    } bind def
    %
    % Call clearStatus and prints out what status we want
    /showStatus
    {
      gsave
      clearStatus
      0.0 setgray
      10 10 moveto
      fntStoreAdx setfont
      100 string cvs show
      grestore
    } bind def
    %
    %  =====================================================
    % |                 General routines                    |
    %  =====================================================
    % Return the max height of the current font
    /textHeight {
        gsave                               % save graphic context
            10 10 moveto                    % move to some point
            (Hpg) true charpath pathbbox    % gets text path bounding box
                                            % (LLx LLy URx URy)
            pop exch pop sub abs            % Returns the absolute value of llX-URx
        grestore                            % restore graphic context
    } bind def
    %
    % Return the max character width of the current font
    /textWidth {
        gsave                               % save graphic context
            10 10 moveto                    % move to some point
            (Hpg) true charpath pathbbox    % gets text path bounding box
                                            % (LLx LLy URx URy)
            exch pop sub exch pop abs       % Returns the absolute value of LLy-URy
        grestore                            % restore graphic context
    } bind def
    %
    /nextLine {
        0 textHeight 0.75 mul neg rmoveto   % move down only in Y axis
    } bind def
    %
    % Right justify text
    /rJustify {dup stringwidth pop neg 0 rmoveto} bind def
    %
    % Center justify the text
    /cJustify {dup stringwidth pop 2 div neg 0 rmoveto} bind def
    %
    % Returns current X or Y position
    /currY { currentpoint exch pop } bind def
    /currX { currentpoint pop} bind def
    %
    %  =====================================================
    % |            Invoice specific commands                |
    %  =====================================================
    %
    % Testing - show the major sections
    /showSections
    {
      % General page layout sections
      .25 setlinewidth
      gsave
      % Specific box areas
      gsave
      [3 6] 2 setdash
      boxStoreX boxStoreY boxStoreW boxStoreH rectstroke
      boxInvoiceX boxInvoiceY boxInvoiceW boxInvoiceH rectstroke
      boxBillX boxBillY boxBillW boxBillH rectstroke
      boxShipX boxShipY boxShipW boxShipH rectstroke
      boxSalesX boxSalesY boxSalesW boxSalesH rectstroke
      boxItemHeadX boxItemHeadY boxItemHeadW boxItemHeadH rectstroke
      boxItemX boxItemY boxItemW boxItemH rectstroke
      boxMemoX boxMemoY boxMemoW boxMemoH rectstroke
      boxTotalX boxTotalY boxTotalW boxTotalH rectstroke
      grestore
    } bind def
    %
    % Abletronics logo
    /ableLogo {
      0.1 setlinewidth
      newpath
      0 0 moveto
      % Show the outline of the total logo
      % 0 0 102 27 rectstroke
      %
      % "A" with logo
      1 1 translate
      % 0 0 75 25 rectstroke
      {
        {
          0 0 75 27 0 5 6 20 4 0 -6 -20 2 21 2 4 4 0 0 -4 5 10 0 4 6 0 0 -4 -6 0
          12 5 -6 20 4 0 6 -20 14 0 -1 -1 18 0 -1 -1 28 0 -38 -3 1 1 -16 0 1 1 -9.5 0
        }
        < 00 01 23 04 0A 01 23 04 0A 01 24 04 0A 01 2D 04 0A >
      } ufill
      %
      % "B"
      15 7 translate
      %0 0 7 10 rectstroke
      {
        {
        0 0 10 15 1 0 0 8 -1 0 1 2 3 0 0 -2 -1 0 0 -2 1 0 0 -2 -1 0
        0 -2 1 0 0 -2 -1 0 4 10 5 7 3 90 315 5 3 3 45 270 -1 0 0 2
        5 3 1 270 90 -2 0 0 2 5 7 1 270 90 -2 0
        }
        < 00 01 2E 04 0A 01 08 08 04 04 07 04 04 07 04 0A >
      } ufill
      %
      % "L"
      9 0 translate
      % 0 0 5 10 rectstroke
      {
        { 0 0 5 10 1 0 0 8 -1 0 1 2 2 0 0 -8 2 0 -1 -2  }
        < 00 01 27 04 0A >
      } ufill
      %
      % "E"
      5 0 translate
      % 0 0 8 11 rectstroke
      {
        { 0 0 8 11 1 0 0 8 -1 0 1 2 3 0 0.5 0.5 3 0 -2
          -2.5 -2.5 0 0 -2 4 0 -1 -2 -3 0 0 -2 4 0 -1 -2 }
        < 00 01 28 04 27 04 0A >
      } ufill
      %
      % "T" with lightning bolt
      4 -2 translate
      % 0 0 69 21 rectstroke
      {
        { 0 0 69 21 8 0 0 15 -8 0 3 5 14 0 -1 -1  14 0 -1 -1 14 0 -1 -1 24 -2
        -30 -1 1 1 -14 0 1 1 -11.5 0 0 -16 }
        < 00 01 30 04 0A >
      } ufill
      %
      % "R"
      15 2 translate
      % 0 0 10 10 rectstroke
      {
        { 0 0 10 10 1 0 0 8 -1 0 1 2 4 0 0 -2 -2 0 0 -2 2 0 0 -2 -2 0 0 -4
        5 8 5 7 3 90 270 0 2 5 7 1 270 90 5.5 4.1 3.5 -4.1 -2.5 0 -3.5 4 }
        < 00 01 2B 04 0A 01 08 04 07 01 04 04 04 0A >
      } ufill
      %
      % "O"
      9 0 translate
      % 0 0 10 10 rectstroke
      {
        { 0 0 10 10 0 5 5 5 5 180 0 -2 0 5 5 2.5 0 180
          0 5 5 5 5 180 0 -2 0 5 5 2.5 0 180 }
        < 00 01 08 04 07 0A 01 07 04 08 0A >
      } ufill
      %
      % "N"
      11 0 translate
      % 0 0 8 10 rectstroke
      {
        {
        0 0 8 10 01 00
        00 08 -1 0 1 2 2 0
        3 -5.5 0 5.5 2 0 0 -10 -2 0
        -3 5.5 0 -5.5
        }
        < 00 01 2B 04 0A >
      } ufill
      %
      % "I"
      9.5 0 translate
      % 0 0 3 10 rectstroke
      {
        { 0 0 3 10 1 0 0 8 -1 0 1 2 2 0 0 -10 }
        < 00 01 25 04 0A >
      } ufill
      %
      % "C"
      4.5 0 translate
      % 0 0 9 10 rectstroke
      {
        { 0 0 9 10 8 8 5 5 5 45 315 -1 1 5 5 2.75 315 45 1 1 }
        < 00 01 07 04 08 04 0A >
      } ufill
      %
      % "S"
      9 0 translate
      % 0 0 8 10 rectstroke
      {
        {
        0 0 8 10  5.25 8 4 7 2.5 45 215 4.15 7 1 200 45 5.25 3.75 4 2.5 2.5 45 215
        4 2.5 1 200 45 1.95 5.60 2.75 -2.4 1.1 1.05 -2.6 2.35 2 1 0 2.2 0.99 -1.05
        4.9 7.7 1.2 -1 -0.2 1.95 -0.1 0.1
        }
        < 00 01 07 08 0A 01 08 07 0A 01 23 04 0A 01 04 04 0A 01 23 04 0A >
      } ufill
    } bind def
    %
    % Show the watermark
    /showWaterMark {
      gsave
      boxItemX 135 add boxItemY 40 add translate 40 rotate
      0.9 setgray 4 4 scale ableLogo
      grestore
    } bind def
    %
    % Show the invoice box
    /showInvoiceBox
    {
      gsave
      boxInvoiceX boxInvoiceY translate
      newpath
      /boxInvSec {boxInvoiceH 5 div} def
      % Draw the boxes
      0 boxInvSec 3 mul moveto
      boxInvoiceW 0 rlineto
      0 boxInvoiceH currY sub boxRadius sub rlineto
      currX boxRadius sub currY boxRadius 0 90 arc
      boxInvoiceW neg boxRadius 2 mul add 0 rlineto
      currX currY boxRadius sub boxRadius 90 180 arc
      closepath fill
      0 0 boxInvoiceW boxInvoiceH boxRadius sub rectstroke
      % Write the text
      1.0 setgray
      pageTitle (pack) eq
      {
        fntInvoiceHead setfont
        boxInvoiceW 2 div boxInvoiceH moveto
        nextLine (Packing Slip) cJustify show
      }
      {
        fntStoreName setfont
        boxInvoiceW 2 div boxInvSec 3.7 mul moveto
        (Invoice) cJustify show
      } ifelse
      0.0 setgray
      fntInvoiceText setfont
      boxInvoiceW 2 idiv boxInvSec 2 mul moveto
      ( Order : ) rJustify show (${invInfo_NUMBER}) show
      boxInvoiceW 2 idiv currY moveto
      nextLine ( Date : ) rJustify show (${invInfo_DATE}) show
      boxInvoiceW 2 idiv currY moveto
      nextLine ( Page : ) rJustify show pageCurrent (   ) cvs show
      ( of ) show pagesTotal (   ) cvs show
      grestore
    } bind def
    %
    % Show store return address
    /showStoreAddress {
      % Show the logo at the top
      gsave boxStoreX boxStoreY boxStoreH add 40 sub translate 1.5 1.5 scale ableLogo grestore
      gsave
      boxStoreX boxStoreY translate
      newpath
      0 boxStoreH 35 sub moveto
      fntStoreBite setfont
      nextLine ($(echo "${adxAble_TAG}")) show 0 currY moveto
      fntStoreAdx setfont
      nextLine ($(echo "${adxAble_STREET}")) show 0 currY moveto
      nextLine ($(echo "${adxAble_CITY}, ${adxAble_STATE} ${adxAble_ZIP}"))
      show 0 currY moveto
      nextLine ($(echo "Phone: ${adxAble_PHONE}  Fax: ${adxAble_FAX}")) show 0 currY moveto
      nextLine ($(echo "Web  : ${adxAble_WEB}")) show 0 currY moveto
      grestore
    } bind def

    %
    % Show the sales info
    /showSalesInfo {
      fntInvoiceText setfont
      gsave
      0.5 setlinewidth
      boxSalesX boxSalesY translate
      % At this point, all references are to 0 0
      % Draw the filled area and lines
        0 boxSalesH 2 idiv moveto
      boxSalesW 0 rlineto
      0 boxSalesH 2 idiv boxRadius sub rlineto
      currX boxRadius sub currY boxRadius 0 90 arc
      boxSalesW boxRadius 2 mul sub neg 0 rlineto
      currX currY boxRadius sub boxRadius 90 180 arc
      closepath fill
      0 0 boxSalesW boxSalesH 2 div rectstroke
      boxSalesPerson 0 moveto 0 boxSalesH 2 idiv rlineto stroke
      boxSalesShip 0 moveto 0 boxSalesH 2 idiv rlineto stroke
      boxSalesDate 0 moveto 0 boxSalesH 2 idiv rlineto stroke
      boxSalesTerms 0 moveto 0 boxSalesH 2 idiv rlineto stroke
      % Show text
      1.0 setgray
      0 boxSalesH 2 idiv 10 add moveto
      boxSalesPO boxSalesSecW 2 idiv add currY moveto (Purchase Order  ) cJustify show
      boxSalesPerson boxSalesSecW 2 idiv add currY moveto (Salesman) cJustify show
      boxSalesShip boxSalesSecW 2 idiv add currY moveto (Shipped Via) cJustify show
      boxSalesDate boxSalesSecW 2 idiv add currY moveto (Ship Date) cJustify show
      boxSalesTerms boxSalesSecW 2 idiv add currY moveto (Terms   ) cJustify show
      0.0 setgray 0 10 moveto
      boxSalesPO currY moveto (${invInfo_PO}) show
      boxSalesPerson 30 add currY moveto (${invInfo_SALES}) show
      boxSalesShip 20 add currY moveto (${invInfo_SHIPTYPE}) show
      boxSalesDate 20 add currY moveto (${invInfo_SHIPDATE}) show
      boxSalesTerms 20 add currY moveto (${invInfo_TERMS}) show
      grestore
    } bind def
    %
    % Show the items header and lines
    /showItemsBoxes {
      gsave
      boxItemX boxItemY moveto
      boxItemX boxItemY boxItemW boxItemH rectstroke
      boxItemShip boxItemY moveto 0 boxItemH rlineto
      boxItemBack boxItemY moveto 0 boxItemH rlineto
      boxItemCode boxItemY moveto 0 boxItemH rlineto
      boxItemVendor boxItemY moveto 0 boxItemH rlineto
      boxItemDesc boxItemY moveto 0 boxItemH rlineto
      pageTitle (pack) ne {
        boxItemUI boxItemY moveto 0 boxItemH rlineto
        boxItemExtended boxItemY moveto 0 boxItemH rlineto
      } if
      stroke
      grestore
      gsave
      boxItemHeadX boxItemHeadY translate
      fntItemHead setfont
      0 0 moveto
      0 0 boxItemHeadW boxItemHeadH rectfill
      1.0 setgray
      boxItemShip 8 add boxItemHeadH 2 div 5 add moveto (Quantity) cJustify show
      boxItemCode currY moveto (Item) show
      boxItemVendor 25 add currY moveto (Vendor) show
      pageTitle (pack) ne {
        boxItemUI 20 add currY moveto (Price) show
      } if
      boxItemOrder 10 moveto (Order) show
      boxItemShip 8 sub currY moveto (Shipped) show
      boxItemBack 12 sub currY moveto (Backorder) show
      boxItemCode currY moveto (Code) show
      boxItemVendor 10 sub currY moveto (ID) show
      boxItemDesc 40 sub currY moveto (Part) rJustify show
      boxItemDesc 20 add currY moveto (Description) show
      pageTitle (pack) ne {
        boxItemUI currY moveto (Unit) show
        boxItemExtended 5 sub currY moveto (Extended) show
      } if
      grestore
    } bind def
    %
    % Show a line item
    /showItemLine {
      % We should receive an array of items here
      % 0 - invItems_ORDER
      % 1 - invItems_SHIPPED
      % 2 - invItems_BACK
      % 3 - invItems_ITEM
      % 4 - invItems_VENDOR
      % 5 - invItems_DESCRIPTION
      % 6 - invItems_PRICEUI
      % 7 - invItems_PRICETOT
      pop % # Array count - don't need it
      pageTitle (pack) ne
      {
        boxItemX 5 sub boxItemW add currY moveto rJustify show % Extended price
        boxItemExtended 5 sub currY moveto rJustify show % Unit price
      }
      { pop pop }
      ifelse
      boxItemDesc 3 add currY moveto show % Description
      boxItemVendor 3 add currY moveto show % Vendor info
      boxItemCode 5 add currY moveto show % item code
      boxItemCode 5 sub currY moveto rJustify show % backordered
      boxItemBack 5 sub currY moveto rJustify show % shipped
      boxItemShip 5 sub currY moveto rJustify show % ordered
    } bind def
    %
    % Loop through the item list
    /showItems {
      gsave
      fntInvoiceItem setfont
      boxItemX boxItemHeadY moveto nextLine
      {
        aload showItemLine pop
        boxItemX currY moveto nextLine
      } forall
      grestore
    } bind def
    %
    % Show Memo lines
    /showMemo {
      gsave
      fntInvoiceText setfont
      boxMemoX 10 add boxMemoY boxMemoH add moveto
    $(
      for (( i=0; i< ${#invMemo[@]}; ++i)) ; do
        echo -en "  nextLine (${invMemo[$i]}) dup show rJustify pop\n"
      done
    )
      grestore
    } bind def
    %
    % Show signature on store copy
    /showSignature {
      gsave
      boxMemoX 10 add boxMemoY 5 add moveto
      (Signature:                           Date: ) show
      grestore
    } bind def
    %
    % Show subtotal, tax, freight, total
    /showTotal {
      gsave
      % Show the labels first
      fntInvoiceText setfont
      boxTotalX 10 add boxTotalY boxTotalH add moveto
      nextLine (Subtotal:) dup show rJustify pop
      nextLine (Tax:) dup show rJustify pop
      nextLine (Freight:) dup show rJustify pop
      fntInvoiceHead setfont
      nextLine (TOTAL:) show
      % Now show the values right justified
      fntInvoiceText setfont
      boxTotalX boxTotalW add 10 sub boxTotalY boxTotalH add moveto
      nextLine (${invInfo_SUBTOTAL}) rJustify show
      nextLine (${invInfo_TAX}) rJustify show
      nextLine (${invInfo_FREIGHT}) rJustify show
      fntInvoiceHead setfont
      nextLine (${invInfo_TOTAL}) rJustify show
      grestore
    } bind def
    %
    % Show billing/shipping address
    /showAddress {
      % array showAddress
      { show 0 currY moveto nextLine } forall
    } bind def
    %
    /showBillingAdx {
      gsave
      fntStoreBite setfont
      boxBillX boxBillY translate
      0 boxBillH moveto
      nextLine (Bill to: ) rJustify show 0 currY moveto
      (${invBill[0]}) show 0 currY moveto
      nextLine billAdx showAddress
      grestore
    } bind def
    %
    /showShippingAdx {
      gsave
      fntStoreBite setfont
      boxShipX boxShipY translate
      0 boxShipH moveto
      nextLine (Ship to: ) rJustify show 0 currY moveto
      (${invShip[0]}) show 0 currY moveto
      nextLine shipAdx showAddress
      grestore
    } bind def
    %
    %  =====================================================
    % |          Build the invoice page                     |
    %  =====================================================
    /showInvoice {
      /pageCurrent 0 def
      itemList {
        /pageCurrent pageCurrent 1 add def
        % showSections % Test line for arranging page
        showWaterMark
        showStoreAddress
        showInvoiceBox
        showBillingAdx
        showShippingAdx
        showSalesInfo
        showItemsBoxes
        showMemo
        pageTitle (store) eq {
          pageCurrent pagesTotal eq {
            showSignature
          } if
        } if
        pageTitle (pack) ne {
          pageCurrent pagesTotal eq {
            showTotal
          } if
        } if
        aload showItems
        pageCurrent pagesTotal lt
        { fntInvoiceText setfont
          boxItemX boxItemW 2 div add boxItemY 5 add moveto
          (Continued on next page) cJustify show
        } if
        showpage
      } forall
    } bind def
    %
    % Time to build the invoice page
    /pageTitle (store) def showInvoice % Store copy of invoice
    /pageTitle (cust) def showInvoice  % Customer copy of invoice
    /pageTitle (pack) def showInvoice  % Packing slip copy

    %%EOF
HERE

    } >"${filePS}"
    dbg ${dbg_LOOP} "Closing fdMain"
    exec 9<&-
    printMe ${filePS}
    rmTmpfiles
fi
