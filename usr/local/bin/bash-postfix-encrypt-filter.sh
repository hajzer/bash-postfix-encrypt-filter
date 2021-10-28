#!/bin/bash
##################################################################################
# BASH Postfix Encrypt Filter
##################################################################################
#
# FILE    : bash-postfix-encrypt-filter.sh
# AUTHOR  : Ladislav Hajzer
# DATE    : 2019
# VERSION : 0.1
# HISTORY :
#           0.1 - Initial version with S/MIME and PGP/MIME support
#
# TODO    :
#           - Exception list with grep (need to perform benchmark). Cons of using grep is new dependency.
#           - Refactoring
#
##################################################################################
# SCRIPT USER SETTINGS
##################################################################################

#
# ARCHIVING
#
# ARCHIVE_ORIGINAL  - Enable (1) or disable (0) archiving of input clear email messages
# ARCHIVE_ENCRYPTED - Enable (1) or disable (0) archiving of output encrypted email messages
# ARCHIVE_RETENTION - Specify (in days) retention of archived email messages.
#
ARCHIVE_ORIGINAL=1
ARCHIVE_ENCRYPTED=1
ARCHIVE_RETENTION=1

#
# ENCRYPTION
#
# ENCRYPT_PREFERENCE      - Set encryption preference to SMIME (smime) or PGP (pgp).
# ENCRYPT_EXCEPTIONS_FROM - List of sender/source email addresses as exceptions for encryption.
# ENCRYPT_EXCEPTIONS_TO   - List of recipient/destination email addresses as exceptions for encryption.
#
ENCRYPT_PREFERENCE="smime"
ENCRYPT_EXCEPTIONS_FROM="/var/spool/postfix/bash-postfix-encrypt-filter/exceptions_encrypt_from.txt"
ENCRYPT_EXCEPTIONS_TO="/var/spool/postfix/bash-postfix-encrypt-filter/exceptions_encrypt_to.txt"

#
# LOGGING
#
# LOGGING_ENABLED     - Enable (1) or disable (0) logging to file specified by LOGGING_FILE variable.
# LOGGING_DATE_FORMAT - Logging date format (for syntax -> man date)
#
LOGGING_ENABLED=1
LOGGING_DATE_FORMAT="%Y-%m-%d %H:%M:%S (%Z)"


##################################################################################
# INITIALIZATION
##################################################################################

#
# Email variables
#
INSPECT_EMAIL_ID=$$
INSPECT_EMAIL_FROM="$(echo $2 | tr '[A-Z]' '[a-z]')"
INSPECT_EMAIL_TO="$(echo $4 | tr '[A-Z]' '[a-z]')"

#
# Encryption
#
ENCRYPT_SMIME_POSSIBLE=0
ENCRYPT_PGP_POSSIBLE=0


##################################################################################
# SCRIPT INTERNAL SETTINGS
##################################################################################

#
# SCRIPT DIRECTORIES
#
DIRECTORY_BASE="/var/spool/postfix/bash-postfix-encrypt-filter"
DIRECTORY_WORK="$DIRECTORY_BASE/work"
DIRECTORY_PGP="$DIRECTORY_BASE/pgp"
DIRECTORY_SMIME="$DIRECTORY_BASE/smime"
DIRECTORY_ARCHIVE="$DIRECTORY_BASE/archive"
DIRECTORY_LOGGING="$DIRECTORY_BASE/log"

#
# SCRIPT LOGGING FILE
#
LOGGING_FILE="$DIRECTORY_LOGGING/bash-postfix-encrypt-filter.log"

#
# INITIALIZATION OF TEMPORARY VARIABLES FOR INSPECTION
#
INSPECT_DIRECTORY="$DIRECTORY_WORK/$INSPECT_EMAIL_ID"
INSPECT_EMAIL_ORIGINAL="$INSPECT_DIRECTORY/in.$INSPECT_EMAIL_ID"
INSPECT_EMAIL_BACKUP="$INSPECT_EMAIL_ORIGINAL.bck"
INSPECT_EMAIL_ENCRYPTED="$INSPECT_DIRECTORY/in.$INSPECT_EMAIL_ID.enc"
INSPECT_EMAIL_INFORMATION="$INSPECT_DIRECTORY/in.$INSPECT_EMAIL_ID.inf"
INSPECT_EMAIL_TO_SMIME="$DIRECTORY_SMIME/$INSPECT_EMAIL_TO.cer"
INSPECT_EMAIL_TO_PGP="$DIRECTORY_PGP/$INSPECT_EMAIL_TO.asc"

#
# SCRIPT MESSAGES
#
MESSAGE_INSPECT_DIR_CANNOT_CREATE="Cannot create inspection directory '$INSPECT_DIRECTORY'."
MESSAGE_INSPECT_DIR_NOEXIST="Inspection directory '$INSPECT_DIRECTORY' does not exist."
MESSAGE_INSPECT_FILE_CANNOT_SAVE="Cannot save mail to file."
MESSAGE_INSPECT_FILE_CANNOT_BACKUP="Cannot create backup of original message."
MESSAGE_INSPECT_ENCRYPT_SMIME_PROBLEM="Cannot encrypt original message with SMIME."
MESSAGE_INSPECT_ENCRYPT_PGP_PROBLEM="Cannot encrypt original message with PGP/GPG."
MESSAGE_FAIL_SENDING_ORIGINAL_MAIL="MAIL-ID=$INSPECT_EMAIL_ID:Original email message for $INSPECT_EMAIL_TO failed to send."
MESSAGE_FAIL_SENDING_ENCRYPTED_MAIL="MAIL-ID=$INSPECT_EMAIL_ID:Encrypted email message for $INSPECT_EMAIL_TO failed to send."
MESSAGE_FAIL_SENDING_INFORMATION_MAIL="MAIL-ID=$INSPECT_EMAIL_ID:Information email message for $INSPECT_EMAIL_TO failed to send."
MESSAGE_PGP_KEY_CANNOT_IMPORT="MAIL-ID=$INSPECT_EMAIL_ID:PGP/GPG public key for $INSPECT_EMAIL_TO cannot be imported."

#
# LOGGING MESSAGES
#
LOGGING_MESSAGE_INSPECT_DIR_CANNOT_CREATE="MAIL-ID=$INSPECT_EMAIL_ID:Cannot create inspection directory '$INSPECT_DIRECTORY'."
LOGGING_MESSAGE_INSPECT_DIR_NOEXIST="MAIL-ID=$INSPECT_EMAIL_ID:Inspection directory '$INSPECT_DIRECTORY' does not exist."
LOGGING_MESSAGE_INSPECT_FILE_CANNOT_SAVE="MAIL-ID=$INSPECT_EMAIL_ID:Cannot save mail to file."
LOGGING_MESSAGE_INSPECT_FILE_CANNOT_BACKUP="MAIL-ID=$INSPECT_EMAIL_ID:Cannot create backup of original message."
LOGGING_MESSAGE_INSPECT_ENCRYPT_SMIME_PROBLEM="MAIL-ID=$INSPECT_EMAIL_ID:Cannot encrypt original message with SMIME."
LOGGING_MESSAGE_INSPECT_ENCRYPT_PGP_PROBLEM="MAIL-ID=$INSPECT_EMAIL_ID:Cannot encrypt original message with PGP/GPG."
LOGGING_MESSAGE_MAIL_INPUT="MAIL-ID=$INSPECT_EMAIL_ID:Email message entered the filter."
LOGGING_MESSAGE_MAIL_BACKUP="MAIL-ID=$INSPECT_EMAIL_ID:Creating backup of the original email message."
LOGGING_MESSAGE_MAIL_SENDER_ENCRYPTION_EXCEPTION="MAIL-ID=$INSPECT_EMAIL_ID:Sender/Source email address $INSPECT_EMAIL_FROM is listed in encryption exception list = no encryption will be applied."
LOGGING_MESSAGE_MAIL_RECIPIENT_ENCRYPTION_EXCEPTION="MAIL-ID=$INSPECT_EMAIL_ID:Recipient/Destination email address $INSPECT_EMAIL_TO is listed in encryption exception list = no encryption will be applied."
LOGGING_MESSAGE_MAIL_RECIPIENT_CHANGE="MAIL-ID=$INSPECT_EMAIL_ID:Recipient changed to $INSPECT_EMAIL_TO."
LOGGING_MESSAGE_MAIL_ENCRYPT_PREFERENCE="MAIL-ID=$INSPECT_EMAIL_ID:Global encryption preference is $ENCRYPT_PREFERENCE."
LOGGING_MESSAGE_MAIL_ENCRYPT_PGP_POSSIBLE="MAIL-ID=$INSPECT_EMAIL_ID:PGP/GPG encryption for $INSPECT_EMAIL_TO is possible."
LOGGING_MESSAGE_MAIL_ENCRYPT_PGP_NOT_POSSIBLE="MAIL-ID=$INSPECT_EMAIL_ID:PGP/GPG encryption for $INSPECT_EMAIL_TO is not possible!"
LOGGING_MESSAGE_MAIL_ENCRYPT_SMIME_POSSIBLE="MAIL-ID=$INSPECT_EMAIL_ID:SMIME encryption for $INSPECT_EMAIL_TO is possible."
LOGGING_MESSAGE_MAIL_ENCRYPT_SMIME_NOT_POSSIBLE="MAIL-ID=$INSPECT_EMAIL_ID:SMIME encryption for $INSPECT_EMAIL_TO is not possible!"
LOGGING_MESSAGE_MAIL_ENCRYPTED_SMIME="MAIL-ID=$INSPECT_EMAIL_ID:Email message for $INSPECT_EMAIL_TO was successfully encrypted with SMIME."
LOGGING_MESSAGE_MAIL_ENCRYPTED_PGP="MAIL-ID=$INSPECT_EMAIL_ID:Email message for $INSPECT_EMAIL_TO was successfully encrypted with PGP/GPG."
LOGGING_MESSAGE_MAIL_ENCRYPTION_NOT_POSSIBLE="MAIL-ID=$INSPECT_EMAIL_ID:Email message for $INSPECT_EMAIL_TO is not possible to encrypt with SMIME or PGP/GPG."
LOGGING_MESSAGE_FAIL_SENDING_ORIGINAL_MAIL="MAIL-ID=$INSPECT_EMAIL_ID:Original email message for $INSPECT_EMAIL_TO failed to send."
LOGGING_MESSAGE_FAIL_SENDING_ENCRYPTED_MAIL="MAIL-ID=$INSPECT_EMAIL_ID:Encrypted email message for $INSPECT_EMAIL_TO failed to send."
LOGGING_MESSAGE_FAIL_SENDING_INFORMATION_MAIL="MAIL-ID=$INSPECT_EMAIL_ID:Information email message for $INSPECT_EMAIL_TO failed to send."
LOGGING_MESSAGE_SENDING_ORIGINAL_MAIL_FROM="MAIL-ID=$INSPECT_EMAIL_ID:Original email message for $INSPECT_EMAIL_TO was successfully sended (source email address is listed in encryption exception list)."
LOGGING_MESSAGE_SENDING_ORIGINAL_MAIL_TO="MAIL-ID=$INSPECT_EMAIL_ID:Original email message for $INSPECT_EMAIL_TO was successfully sended (destination email address is listed in encryption exception list)."
LOGGING_MESSAGE_SENDING_INFORMATION_MAIL="MAIL-ID=$INSPECT_EMAIL_ID:Information email message for $INSPECT_EMAIL_TO was successfully sended."
LOGGING_MESSAGE_SENDING_ENCRYPTED_MAIL="MAIL-ID=$INSPECT_EMAIL_ID:Encrypted email message for $INSPECT_EMAIL_TO was successfully sended."
LOGGING_MESSAGE_PGP_KEY_CANNOT_IMPORT="MAIL-ID=$INSPECT_EMAIL_ID:PGP/GPG public key for $INSPECT_EMAIL_TO cannot be imported."

#
# INFORMATION EMAIL
#
INFORMATION_EMAIL_BODY="Dear recipient,\n"
INFORMATION_EMAIL_BODY+="\n"
INFORMATION_EMAIL_BODY+="email message from address '$INSPECT_EMAIL_FROM' was targeted to your address '$INSPECT_EMAIL_TO', but our email system dont have your S/MIME certificate or PGP/GPG public key. If you want to receive encrypted messages please send your S/MIME certificate or PGP/GPG public key to email address smime_pgp@this-domain.com.\n"
INFORMATION_EMAIL_BODY+="\n"
INFORMATION_EMAIL_BODY+="Thank you for your understanding and cooperation.\n"
INFORMATION_EMAIL_BODY+="\n"
INFORMATION_EMAIL_BODY+="Best regards\n"
INFORMATION_EMAIL_BODY+="This-domain.com team\n"

#
# EXIT CODES FROM <sysexits.h>
#
EX_TEMPFAIL=75
EX_UNAVAILABLE=69

#
# COMMANDS
#
SENDMAIL="/usr/sbin/sendmail -G -i" # NEVER NEVER NEVER use "-t" here. The -G option does nothing before Postfix 2.3.
FORMAIL="/bin/formail"
GPG="/bin/gpg2"
DATE="/bin/date"
OPENSSL="/bin/openssl"
CD="/bin/cd"
CAT="/bin/cat"
CP="/bin/cp"
RM="/bin/rm"
RMDIR="/bin/rmdir"
AWK="/bin/awk"
MKDIR="/bin/mkdir"
ECHO="/bin/echo"
PRINTF="/bin/printf"
FIND="/bin/find"


##################################################################################
# FUNCTIONS
##################################################################################


function logger_date () {

    local MSG_DATE

    MSG_DATE=$("$DATE" "+$LOGGING_DATE_FORMAT")
    echo "$MSG_DATE"
}

function logger () {

    local MSG_DATE=$1
    local MSG_OUTPUT=$2

    echo "$MSG_DATE $MSG_OUTPUT" >> $LOGGING_FILE
}

function encrypt_pgp_possible () {

    if [ -e "$INSPECT_EMAIL_TO_PGP" ];
    then
        ENCRYPT_PGP_POSSIBLE=1
    else
        ENCRYPT_PGP_POSSIBLE=0
    fi
}

function encrypt_smime_possible () {

    if [ -e "$INSPECT_EMAIL_TO_SMIME" ];
    then
        ENCRYPT_SMIME_POSSIBLE=1
    else
        ENCRYPT_SMIME_POSSIBLE=0
    fi
}

function encrypt_smime (){

    local EMAIL_ORIGINAL="$1"
    local EMAIL_ENCRYPTED="$2"
    local EMAIL_FROM="$3"
    local EMAIL_TO="$4"
    local EMAIL_SUBJECT="$5"
    local EMAIL_TO_CERT="$6"

    $OPENSSL smime -encrypt -in "$EMAIL_ORIGINAL" -out "$EMAIL_ENCRYPTED" -from "$EMAIL_FROM" -to "$EMAIL_TO" -subject "$EMAIL_SUBJECT" "$EMAIL_TO_CERT" || { echo "$MESSAGE_INSPECT_ENCRYPT_SMIME_PROBLEM"; exit $EX_TEMPFAIL; }
}

function encrypt_pgp_mime (){

    local EMAIL_ORIGINAL="$1"
    local EMAIL_ENCRYPTED="$2"
    local EMAIL_TO="$3"
    local EMAIL_TO_KEY="$4"

    local BOUNDARY
    local PGP_MIME_HEADER_BOUNDARY
    local PGP_MIME_HEADER_START
    local PGP_MIME_HEADER_END

    local PGP_MIME_EMAIL_HEADER=$INSPECT_DIRECTORY/pgp_mime_email_header
    local PGP_MIME_EMAIL_BODY=$INSPECT_DIRECTORY/pgp_mime_email_body

    # Generate MIME boundary
    BOUNDARY=$(uuidgen -t)
    PGP_MIME_HEADER_BOUNDARY="--"
    PGP_MIME_HEADER_BOUNDARY+=$(echo $BOUNDARY)

    # Define PGP/MIME start
    PGP_MIME_HEADER_START=`echo "$PGP_MIME_HEADER_BOUNDARY\n"`
    PGP_MIME_HEADER_START+="Content-Type: application/pgp-encrypted\n"
    PGP_MIME_HEADER_START+="Content-Description: PGP/MIME version identification\n"
    PGP_MIME_HEADER_START+="\n"
    PGP_MIME_HEADER_START+="Version: 1\n"
    PGP_MIME_HEADER_START+="\n"
    PGP_MIME_HEADER_START+=`echo "$PGP_MIME_HEADER_BOUNDARY\n"`
    PGP_MIME_HEADER_START+="Content-Type: application/octet-stream; name=\"encrypted.asc\"\n"
    PGP_MIME_HEADER_START+="Content-Description: OpenPGP encrypted message\n"
    PGP_MIME_HEADER_START+="Content-Disposition: inline; filename=\"encrypted.asc\"\n"

    # Define PGP/MIME end
    PGP_MIME_HEADER_END="\n"
    PGP_MIME_HEADER_END+=`echo "$PGP_MIME_HEADER_BOUNDARY"`
    PGP_MIME_HEADER_END+="--\n"

    # Extract "From:", "To:", "Subject:", "Date:", "MIME-Version:" from email header of the original email to temporary file "pgp_mime_email_header"
    $CAT $EMAIL_ORIGINAL | $FORMAIL -c -X "From:" -X "To:" -X "Subject:" -X "Date:" -X "MIME-Version:" > $PGP_MIME_EMAIL_HEADER

    # Add "Content-Type:" email header to temporary file "pgp_mime_email_header"
    $ECHO -e "Content-Type: multipart/encrypted; boundary=$BOUNDARY; protocol=\"application/pgp-encrypted\"\n" >> $PGP_MIME_EMAIL_HEADER

    # Add PGP/MIME start (Content-Types: application/pgp-encrypted and application/octet-stream) to temporary file "pgp_mime_email_header"
    $ECHO -e $PGP_MIME_HEADER_START >> $PGP_MIME_EMAIL_HEADER

    # Extract "Content-Type" from email header to temporary file "pgp_mime_email_body"
    $CAT $EMAIL_ORIGINAL | $FORMAIL -X "Content-Type:" > $PGP_MIME_EMAIL_BODY

    # Extract body of the email to temporary file "pgp_mime_email_body"
    $CAT $EMAIL_ORIGINAL | $FORMAIL -I "" >> $PGP_MIME_EMAIL_BODY

    # Add PGP/MIME header to the new PGP/MIME encrypted email
    $CAT $INSPECT_DIRECTORY/pgp_mime_email_header > $EMAIL_ENCRYPTED

    # Check if PGP public key is imported in GPG keyring
    # If not import public key to GPG keyring
    $GPG --list-keys $EMAIL_TO_KEY
    if [ $? -ne 0 ];
        then
        {
            $GPG --import $EMAIL_TO_KEY ||
            {
                echo $MESSAGE_PGP_KEY_CANNOT_IMPORT;
                if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$LOGGING_MESSAGE_PGP_KEY_CANNOT_IMPORT"; fi
                exit $EX_TEMPFAIL;
            }
        }
    fi

    # Encrypt PGP/MIME email body and paste ("argument --output -") to the new PGP/MIME encrypted email
    $GPG --no-verbose --no-tty --quiet --batch --yes --encrypt --output -  --armor --textmode --always-trust -r $EMAIL_TO $PGP_MIME_EMAIL_BODY >> $EMAIL_ENCRYPTED

    # Add PGP/MIME end (Boundary of PGP/MIME email)
    $ECHO -e $PGP_MIME_HEADER_END >> $EMAIL_ENCRYPTED

    # Remove temporary files
    $RM -rf $PGP_MIME_EMAIL_HEADER
    $RM -rf $PGP_MIME_EMAIL_BODY
}

function purge_archive (){

    # Remove old archived email messages and archive directories
    local RETENTION="+$ARCHIVE_RETENTION"
    $CD $DIRECTORY_ARCHIVE
    $FIND "$DIRECTORY_ARCHIVE" -type f -mtime $RETENTION -exec $RM -rf {} +
    $FIND "$DIRECTORY_ARCHIVE" -type d -mtime $RETENTION -exec $RM -rf {} +
}

function cleaning (){

    # Remove working files and directory
    $RM -rf "$INSPECT_EMAIL_ORIGINAL"
    $RM -rf "$INSPECT_EMAIL_BACKUP"
    $RM -rf "$INSPECT_EMAIL_ENCRYPTED"
    $RM -rf "$INSPECT_EMAIL_INFORMATION"
    $RMDIR --ignore-fail-on-non-empty "$INSPECT_DIRECTORY"
}


##################################################################################
# MAIN
##################################################################################

# Clean up when done or when aborting
trap "rm -f in.$$" 0 1 2 3 15


# Create temporary working directory for specific message
$MKDIR -p $INSPECT_DIRECTORY ||
{
    echo $MESSAGE_INSPECT_DIR_CANNOT_CREATE;
    if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$LOGGING_MESSAGE_INSPECT_DIR_CANNOT_CREATE"; fi
    exit $EX_TEMPFAIL;
}


# Change working directory to INSPECT_DIRECTORY
$CD $INSPECT_DIRECTORY ||
{
     echo $MESSAGE_INSPECT_DIR_NOEXIST;
     if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$LOGGING_MESSAGE_INSPECT_DIR_NOEXIST"; fi
     exit $EX_TEMPFAIL;
}


# Save original (non-filtered) message to inspect directory
$CAT > $INSPECT_EMAIL_ORIGINAL ||
{
    echo $MESSAGE_INSPECT_FILE_CANNOT_SAVE;
    if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$LOGGING_MESSAGE_INSPECT_FILE_CANNOT_SAVE"; fi
    exit $EX_TEMPFAIL;
}
if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$LOGGING_MESSAGE_MAIL_INPUT"; fi


# Create backup of the original message
$CP $INSPECT_EMAIL_ORIGINAL $INSPECT_EMAIL_BACKUP ||
{
    echo $MESSAGE_INSPECT_FILE_CANNOT_BACKUP;
    if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$MESSAGE_INSPECT_FILE_CANNOT_BACKUP"; fi
    exit $EX_TEMPFAIL;
}
if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$LOGGING_MESSAGE_MAIL_BACKUP"; fi


# Replace multiple recipients in Header "To:" to single recipient in ORIGINAL message
$CAT $INSPECT_EMAIL_BACKUP | formail -I "To: $INSPECT_EMAIL_TO" > $INSPECT_EMAIL_ORIGINAL ||
{
    echo $MESSAGE_INSPECT_FILE_CANNOT_BACKUP;
    if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$MESSAGE_INSPECT_FILE_CANNOT_BACKUP"; fi
    exit $EX_TEMPFAIL;
}
if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$LOGGING_MESSAGE_MAIL_RECIPIENT_CHANGE"; fi


# Check encryption exception list (MAIL FROM:)
# If sender email address is listed in the list then send original email message
EXCEPTIONS_LIST=`cat $ENCRYPT_EXCEPTIONS_FROM`
EXCEPTIONS=($EXCEPTIONS_LIST)

for i in "${EXCEPTIONS[@]}"
do

    if [ $i == "$INSPECT_EMAIL_FROM" ];
    then

        # Log information that recipient email address is listed in encryption exception list
        if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$LOGGING_MESSAGE_MAIL_SENDER_ENCRYPTION_EXCEPTION"; fi

        # Send original unencrypted and unmodified email message
        $SENDMAIL "$@" <$INSPECT_EMAIL_ORIGINAL ||
        {
            echo $MESSAGE_FAIL_SENDING_ORIGINAL_MAIL;
            if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$LOGGING_MESSAGE_FAIL_SENDING_ORIGINAL_MAIL"; fi
            exit $EX_TEMPFAIL;
        }
        if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$LOGGING_MESSAGE_SENDING_ORIGINAL_MAIL_FROM"; fi

        # Remove old archived email messages and archive directories
        purge_archive

        # Remove working files and directory
        cleaning

        # Exit after sending email
        exit $?
    fi
done


# Unset working variables
unset EXCEPTIONS_LIST
unset EXCEPTIONS


# Check encryption exception list (RCPT TO:)
# If recipient email address is listed in the list then send original email message
EXCEPTIONS_LIST=`cat $ENCRYPT_EXCEPTIONS_TO`
EXCEPTIONS=($EXCEPTIONS_LIST)

for i in "${EXCEPTIONS[@]}"
do

    if [[ $INSPECT_EMAIL_TO == *$i ]];
    then

        # Log information that recipient email address is listed in encryption exception list
        if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$LOGGING_MESSAGE_MAIL_RECIPIENT_ENCRYPTION_EXCEPTION"; fi

        # Send original unencrypted and unmodified email message
        $SENDMAIL "$@" <$INSPECT_EMAIL_ORIGINAL ||
        {
            echo $MESSAGE_FAIL_SENDING_ORIGINAL_MAIL;
            if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$LOGGING_MESSAGE_FAIL_SENDING_ORIGINAL_MAIL"; fi
            exit $EX_TEMPFAIL;
        }
        if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$LOGGING_MESSAGE_SENDING_ORIGINAL_MAIL_TO"; fi

        # Remove old archived email messages and archive directories
        purge_archive

        # Remove working files and directory
        cleaning

        # Exit after sending email
        exit $?
    fi
done


# Store original email subject
INSPECT_EMAIL_SUBJECT=`$CAT $INSPECT_EMAIL_ORIGINAL | $FORMAIL -x Subject`


##################################################################################
# MAIN - ENCRYPTION
##################################################################################

# Check if possible to encrypt email with SMIME
encrypt_smime_possible
if [ $ENCRYPT_SMIME_POSSIBLE -eq 1 ];
then
    if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$LOGGING_MESSAGE_MAIL_ENCRYPT_SMIME_POSSIBLE"; fi
else
    if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$LOGGING_MESSAGE_MAIL_ENCRYPT_SMIME_NOT_POSSIBLE"; fi
fi


# Check if possible to encrypt email with PGP/GPG
encrypt_pgp_possible
if [ $ENCRYPT_PGP_POSSIBLE -eq 1 ];
then
    if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$LOGGING_MESSAGE_MAIL_ENCRYPT_PGP_POSSIBLE"; fi
else
    if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$LOGGING_MESSAGE_MAIL_ENCRYPT_PGP_NOT_POSSIBLE"; fi
fi


# If is possible to encrypt email message with SMIME or PGP/GPG
if [ $ENCRYPT_SMIME_POSSIBLE -eq 1 -o $ENCRYPT_PGP_POSSIBLE -eq 1 ];
then
    # If is possible to encrypt with SMIME and encryption preference is SMIME then encrypt with SMIME.
    if [ $ENCRYPT_SMIME_POSSIBLE -eq 1 -a $ENCRYPT_PREFERENCE == "smime" ]
    then
        # Encrypt original email message with SMIME certificate
        encrypt_smime "$INSPECT_EMAIL_ORIGINAL" \
                      "$INSPECT_EMAIL_ENCRYPTED" \
                      "$INSPECT_EMAIL_FROM" \
                      "$INSPECT_EMAIL_TO" \
                      "$INSPECT_EMAIL_SUBJECT" \
                      "$INSPECT_EMAIL_TO_SMIME" ||
                      {
                          echo $MESSAGE_MAIL_ENCRYPT_SMIME_PROBLEM;
                          if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$LOGGING_MESSAGE_MAIL_ENCRYPT_SMIME_PROBLEM"; fi
                          exit $EX_TEMPFAIL;
                      }
        if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$LOGGING_MESSAGE_MAIL_ENCRYPTED_SMIME"; fi

        # Send encrypted email message
        $SENDMAIL "$@" <$INSPECT_EMAIL_ENCRYPTED ||
        {
            echo $MESSAGE_FAIL_SENDING_ENCRYPTED_MAIL;
            if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$LOGGING_MESSAGE_FAIL_SENDING_ENCRYPTED_MAIL"; fi
            exit $EX_TEMPFAIL;
        }
        if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$LOGGING_MESSAGE_SENDING_ENCRYPTED_MAIL"; fi
    fi


    # If is possible to encrypt with PGP/GPG and encryption preference is PGP then encrypt with PGP/GPG.
    if [ $ENCRYPT_PGP_POSSIBLE -eq 1 -a $ENCRYPT_PREFERENCE == "pgp" ]
    then
        # Encrypt body of the message with PGP/GPG public key
        encrypt_pgp_mime "$INSPECT_EMAIL_ORIGINAL" \
                         "$INSPECT_EMAIL_ENCRYPTED" \
                         "$INSPECT_EMAIL_TO" \
                         "$INSPECT_EMAIL_TO_PGP" ||
                         {
                            echo $MESSAGE_MAIL_ENCRYPT_PGP_PROBLEM;
                            if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$LOGGING_MESSAGE_MAIL_ENCRYPT_PGP_PROBLEM"; fi
                            exit $EX_TEMPFAIL;
                         }
        if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$LOGGING_MESSAGE_MAIL_ENCRYPTED_PGP"; fi

        # Send encrypted email message
        $SENDMAIL "$@" <$INSPECT_EMAIL_ENCRYPTED ||
        {
            echo $MESSAGE_FAIL_SENDING_ENCRYPTED_MAIL;
            if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$LOGGING_MESSAGE_FAIL_SENDING_ENCRYPTED_MAIL"; fi
            exit $EX_TEMPFAIL;
        }
        if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$LOGGING_MESSAGE_SENDING_ENCRYPTED_MAIL"; fi
    fi


    # If is possible to encrypt with SMIME but not for PGP/GPG and encryption preference is PGP then encrypt with SMIME.
    if [ $ENCRYPT_SMIME_POSSIBLE -eq 1 -a $ENCRYPT_PREFERENCE == "pgp" -a $ENCRYPT_PGP_POSSIBLE -ne 1 ]
    then
        # Encrypt original email message with SMIME certificate
        encrypt_smime "$INSPECT_EMAIL_ORIGINAL" \
                      "$INSPECT_EMAIL_ENCRYPTED" \
                      "$INSPECT_EMAIL_FROM" \
                      "$INSPECT_EMAIL_TO" \
                      "$INSPECT_EMAIL_SUBJECT" \
                      "$INSPECT_EMAIL_TO_SMIME" ||
                      {
                          echo $MESSAGE_MAIL_ENCRYPT_SMIME_PROBLEM;
                          if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$LOGGING_MESSAGE_MAIL_ENCRYPT_SMIME_PROBLEM"; fi
                          exit $EX_TEMPFAIL;
                      }
        if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$LOGGING_MESSAGE_MAIL_ENCRYPTED_SMIME"; fi

        # Send encrypted email message
        $SENDMAIL "$@" <$INSPECT_EMAIL_ENCRYPTED ||
        {
            echo $MESSAGE_FAIL_SENDING_ENCRYPTED_MAIL;
            if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$LOGGING_MESSAGE_FAIL_SENDING_ENCRYPTED_MAIL"; fi
            exit $EX_TEMPFAIL;
        }
        if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$LOGGING_MESSAGE_SENDING_ENCRYPTED_MAIL"; fi
    fi


    # If is possible to encrypt with PGP/GPG but not for SMIME and encryption preference is SMIME then encrypt with PGP/GPG.
    if [ $ENCRYPT_PGP_POSSIBLE -eq 1 -a $ENCRYPT_PREFERENCE == "smime" -a $ENCRYPT_SMIME_POSSIBLE -ne 1 ]
    then
        # Encrypt body of the message with PGP/GPG public key
        encrypt_pgp_mime "$INSPECT_EMAIL_ORIGINAL" \
                         "$INSPECT_EMAIL_ENCRYPTED" \
                         "$INSPECT_EMAIL_TO" \
                         "$INSPECT_EMAIL_TO_PGP" ||
                         {
                            echo $MESSAGE_MAIL_ENCRYPT_PGP_PROBLEM;
                            if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$LOGGING_MESSAGE_MAIL_ENCRYPT_PGP_PROBLEM"; fi
                            exit $EX_TEMPFAIL;
                         }
        if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$LOGGING_MESSAGE_MAIL_ENCRYPTED_PGP"; fi

        # Send encrypted email message
        $SENDMAIL "$@" <$INSPECT_EMAIL_ENCRYPTED ||
        {
            echo $MESSAGE_FAIL_SENDING_ENCRYPTED_MAIL;
            if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$LOGGING_MESSAGE_FAIL_SENDING_ENCRYPTED_MAIL"; fi
            exit $EX_TEMPFAIL;
        }
        if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$LOGGING_MESSAGE_SENDING_ENCRYPTED_MAIL"; fi
    fi

else
    # Log if is NOT possible to encrypt email message with SMIME or PGP/GPG
    if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$LOGGING_MESSAGE_MAIL_ENCRYPTION_NOT_POSSIBLE"; fi

    # Extract original email header + add information text as email body
    $CAT $INSPECT_EMAIL_ORIGINAL | $FORMAIL -X "" > $INSPECT_EMAIL_INFORMATION
    $PRINTF "\n" >> $INSPECT_EMAIL_INFORMATION
    $ECHO -e $INFORMATION_EMAIL_BODY >> $INSPECT_EMAIL_INFORMATION

    # Send information email to recipient for which is not possible to send encrypted email
    $SENDMAIL "$@" <$INSPECT_EMAIL_INFORMATION ||
    {
        echo $MESSAGE_FAIL_SENDING_INFORMATION_MAIL;
        if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$LOGGIMG_MESSAGE_FAIL_SENDING_INFORMATION_MAIL"; fi
        exit $EX_TEMPFAIL;
    }
   if [ $LOGGING_ENABLED ]; then logger "$(logger_date)" "$LOGGING_MESSAGE_SENDING_INFORMATION_MAIL"; fi

fi


##################################################################################
# MAIN - ARCHIVING
##################################################################################

ARCH_DATE=$("$DATE" "+%Z-%Y-%m-%d")
ARCH_TIME=$("$DATE" "+%H-%M")

# Archiving of original email message
if [ $ARCHIVE_ORIGINAL -eq 1 ];
then
    # Create directory for archiving original email message
    INSPECT_EMAIL_ARCHIVE_DIRECTORY="$DIRECTORY_ARCHIVE/$ARCH_DATE/$ARCH_TIME/$INSPECT_EMAIL_TO"
    $MKDIR -p "$DIRECTORY_ARCHIVE/$ARCH_DATE/$ARCH_TIME/$INSPECT_EMAIL_TO"

    # Copy original (backuped, non modified) email message to archiving directory for this message
    $CP $INSPECT_EMAIL_BACKUP $INSPECT_EMAIL_ARCHIVE_DIRECTORY
fi

# Archiving of encrypted email message or information email message
if [ $ARCHIVE_ENCRYPTED -eq 1 ];
then
    # Create directory for archiving original email message
    INSPECT_EMAIL_ARCHIVE_DIRECTORY="$DIRECTORY_ARCHIVE/$ARCH_DATE/$ARCH_TIME/$INSPECT_EMAIL_TO"
    $MKDIR -p "$DIRECTORY_ARCHIVE/$ARCH_DATE/$ARCH_TIME/$INSPECT_EMAIL_TO"

    # Copy encrypted email message to archiving directory for this message
    $CP $INSPECT_EMAIL_ENCRYPTED $INSPECT_EMAIL_ARCHIVE_DIRECTORY

    # Copy information email message to archiving directory for this message
    $CP $INSPECT_EMAIL_INFORMATION $INSPECT_EMAIL_ARCHIVE_DIRECTORY
fi


##################################################################################
# MAIN - ARCHIVING - PURGE OLD ARCHIVED EMAIL MESSAGES
##################################################################################

# Remove old archived email messages and archive directories
purge_archive


##################################################################################
# MAIN - CLEANING
##################################################################################

# Remove working files and directory
cleaning


##################################################################################
# MAIN - EXIT
##################################################################################

exit $?
