#!/bin/bash
# ----------------------------------------------------------------------------------------------------
# create-certificate --create [ server.domain.com | *.domain.com ]

# CHECK KEY
# openssl x509 -in rootca.crt -noout -text 

# ----------------------------------------------------------------------------------------------------

# ----------------------------------------------------------------------------------------------------
# GLOBAL VARIABLES
# ----------------------------------------------------------------------------------------------------

FLD1=".certificate"
FLD2="root-certificate"
FLD3="$FLD1/$FLD2"

# ----------------------------------------------------------------------------------------------------
#
# ----------------------------------------------------------------------------------------------------

# --------------------------------------------------
#
# --------------------------------------------------
function Init() {

	mkdir -p $FLD1

	Question_Default "Enter domainname" "domain.com"
	echo "domain=\"$result\"" > $FLD1/certificate.cfg

	Question_Default "Enter Country" "BE"
	echo "country=\"$result\"" >> $FLD1/certificate.cfg

}

# --------------------------------------------------
# Question
# --------------------------------------------------
function Question() {

  space=$((40 - ${#1} ))

	printf '%s%*s' "$1" "$space" " : "
	read result
}

# --------------------------------------------------
# Question with Yes/No option
# --------------------------------------------------
function Question_YN() {

  input=" "
  space=$((40 - ${#1} ))

  until [[ ${input^^} == "Y"  ||  ${input^^} == "N" ||  $input == "" ]]; do
    printf '%s%*s%s' "$1" "$space" "" "[$2] "
    read -s -n 1 input
    printf "\n"
  done

  if [[ $input == "" ]]; then
    input=$2
  fi

  result=${input^^}
}

# --------------------------------------------------
# Question with default value
# --------------------------------------------------
function Question_Default() {

  result=" "
  space=$((40 - ${#1} ))

  printf '%s%*s%s' "$1" "$space" "" "[$2] "
  read result
  printf "\n"
  
  if [[ $result == "" ]]; then
    result=$2
  fi
}

# --------------------------------------------------
# Generate an RSA private key file. [*.pem]
# --------------------------------------------------
crt_root_key () {
	openssl genrsa -out $FLD3/rootca.key 4096
}

# --------------------------------------------------
# Generate a Client Certificate [*.csr]
# --------------------------------------------------
crt_root_crt () {
	# TODO subject opvullen
	openssl req -x509 -new -nodes -key $FLD3/rootca.key -sha256 -days 1024 -subj "/C=BE/ST=BRUSSELS/O=Mohawkey Inc./CN=home.io" -out $FLD3/rootca.crt
}

# ----------------------------------------------------------------------------------------------------
#
# ----------------------------------------------------------------------------------------------------

# CHECK IF CONFIG FILE EXISTS
if [[ ! -f "$FLD1/certificate.cfg" ]]; then
	Init
	exit 0
else
	. $FLD1/certificate.cfg
fi

# CHECK AND CREATE FOLDERS
if [[ ! -d "$FLD1" || ! -d "$FLD3" ]]; then mkdir -p "$FLD3"; fi

# CREATE ROOT.KEY
if [[ ! -f "$FLD3/rootca.key" ]]; then
	Question_YN "Create ROOT Public and Private Key Pair" "Y"
	if [[ $result == "Y" ]]; then
	  crt_root_key
	fi
fi

# CREATE ROOT.CRT
if [[ ! -f "$FLD3/rootca.crt" && -f "$FLD3/rootca.key" ]]; then
	Question_YN "Create ROOT Certificate" "Y"
	if [[ $result == "Y" ]]; then
	  crt_root_crt
	fi
fi

# ----------------------------------------------------------------------------------------------------
#
#
#
# ----------------------------------------------------------------------------------------------------

# IF ROOT KEY and CERTIFICATE EXIST
if [[ -f "$FLD3/rootca.crt" && -f "$FLD3/rootca.key" ]]; then

  # CREATE CERTIFICATE FOR LOCAL DOMAIN
  Question_YN "Create Local Domain Certificate" "Y"
	if [[ $result == "Y" ]]; then

		Question "Enter Domain Name"
		domain=$result

		# ----------------------------------------
		#
		# ----------------------------------------
		if [[ ! -d "$FLD1/$domain" ]]; then

			mkdir -p $FLD1/$domain

			Question "Enter IP-address "
			ip=$result

			openssl genrsa -out $FLD1/$domain/$domain.key 2048
			openssl req -new -sha256 -key $FLD1/$domain/$domain.key -subj "/CN=$domain" -out $FLD1/$domain/$domain.csr

### INSERT

			# Create a extfile with all the alternative names
    	if [[ -e $FLD1/extfile.cnf ]]; then
      	rm $FLD1/extfile.cnf
	    fi

    	echo "subjectAltName=DNS:$domain,IP:$ip" >> $FLD1/extfile.cnf

    	# optional
    	# echo extendedKeyUsage = serverAuth >> extfile.cnf

    	# Create the certificate
    	openssl x509 -req -sha256 -days 365 -in $FLD1/$domain/$domain.csr -CA $FLD3/rootca.crt -CAkey $FLD3/rootca.key -out $FLD1/$domain/$domain.pem -extfile $FLD1/extfile.cnf -CAcreateserial

    	if [[ -e $FLD1/extfile.cnf ]]; then
      	rm $FLD1/extfile.cnf
    	fi

### INSERT

		else
			echo "folder $domain exist"
		fi

	fi

fi
