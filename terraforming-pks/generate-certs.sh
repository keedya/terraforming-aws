#!/bin/bash

#Required
domain=$(terraform output pks_api_endpoint)
commonname="${domain}"

#Change to your company details
country=US
state=MA
locality=HOP
organization=emc.com
organizationalunit=OE
email=andre.keedy@emc.com

password=mypassword

if [ -z "$domain" ]
then
    echo "Argument not present."
    echo "Useage $0 [common name]"

    exit 99
fi

echo "Generating key request for $domain"

#Generate a key
#openssl genrsa -des3 -passout pass:$password -out $domain.key 2048 -noout
openssl genrsa -des3 -passout pass:$password -out $domain.key 2048
#Remove passphrase from the key. Comment the line out to keep the passphrase
openssl rsa -in $domain.key -passin pass:$password -out $domain.key
#Create the request
echo "Creating CSR"
openssl req -new -key $domain.key -out $domain.csr -passin pass:$password \
    -subj "/C=$country/ST=$state/L=$locality/O=$organization/OU=$organizationalunit/CN=$commonname/emailAddress=$email"
#create certificate
openssl x509 -in $domain.csr -out $domain.crt -req -signkey $domain.key -passin pass:$password -days 358000

echo "---------------------------"
echo "-----Below is your CRT-----"
echo "---------------------------"
echo
cat $domain.crt

echo
echo "---------------------------"
echo "-----Below is your Key-----"
echo "---------------------------"
echo
cat $domain.key

export PKS_CERT=$(cat $domain.crt)
export PKS_PRIV_KEY=$(cat $domain.key)
