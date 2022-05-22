#!/bin/bash

domain=$1
wordlist=$2
resolvers="/home/cyberhunter/pentest/wordlists/resolvers.txt"

if [ $# -lt 1 ]
then
    echo "Usage: ./myDnsRecon.sh <DOMAIN> <WORDLIST>=namelist.txt(default)"
    exit 0
fi

if [ $# -lt 2 ]
then
   wordlist="/home/cyberhunter/pentest/wordlists/SecLists/Discovery/DNS/namelist.txt"
fi

echo "WordList : $wordlist"
echo "In Progress...........wait please"

domain_enum(){
    mkdir -p $domain $domain/subdomains $domain/recon $domain/recon/nuclei &&
    echo "execute SubFinder ..." &&
    subfinder -d $domain -o $domain/subdomains/subfinder.txt 1&>/dev/null &&
    echo "execute assetfinder ..." &&
    assetfinder -subs-only $domain | tee $domain/subdomains/assetfinder.txt 1&>/dev/null &&
    echo "execute Amass ..." &&
    amass enum -d $domain -o $domain/subdomains/amass.txt 1&>/dev/null &&
    echo "execute ShuffleDns ..." &&
    shuffledns -d $domain -w $wordlist -r $resolvers -o $domain/subdomains/shuffledns.txt 1&>/dev/null && 
    cat $domain/subdomains/*.txt | sort -u > $domain/subdomains/all.txt
}
domain_enum

resolving_domains(){
    shuffledns -d $domain -list $domain/subdomains/all.txt -r $resolvers -o $domain/domains.txt 1&>/dev/null
}

httprobe(){
    echo "execute httpx ..."
    cat $domain/subdomains/all.txt | httpx -threads 150 -o $domain/recon.txt
}

resolving_domains && httprobe &&

read -p "Scan with Nuclei ? y/n:  " input
if [ $input == "y" ]
then
    read -p "InteractSH-URL (ex: https://azdjzdojdfhzifzrfurhfurf.interact.sh):   " interact
    scanner(){
    cat $domain/recon.txt | nuclei -t /home/cyberhunter/nuclei-templates/cves/ -c 100 -iserver $interact -o $domain/recon/nuclei/cves.txt
    cat $domain/recon.txt | nuclei -t /home/cyberhunter/nuclei-templates/vulnerabilities/ -c 100 -iserver $interact -o $domain/recon/nuclei/vulnerabilities.txt
    cat $domain/recon.txt | nuclei -t /home/cyberhunter/nuclei-templates/file/ -c 100 -iserver $interact -o $domain/recon/nuclei/file.txt
    cat $domain/recon.txt | nuclei -t /home/cyberhunter/nuclei-templates/technologies/ -c 100 -iserver $interact -o $domain/recon/nuclei/technologies.txt
    cat $domain/recon.txt | nuclei -t /home/cyberhunter/nuclei-templates/misconfiguration/ -c 100 -iserver $interact -o $domain/recon/nuclei/misconfiguration.txt
    cat $domain/recon.txt | nuclei -t /home/cyberhunter/nuclei-templates/miscellaneous/ -c 100 -iserver $interact -o $domain/recon/nuclei/miscellaneous.txt
    cat $domain/recon.txt | nuclei -t /home/cyberhunter/nuclei-templates/fuzzing/ -c 100 -iserver $interact -o $domain/recon/nuclei/fuzzing.txt
    cat $domain/recon.txt | nuclei -t /home/cyberhunter/nuclei-templates/exposures/ -c 100 -iserver $interact -o $domain/recon/nuclei/exposures.txt
    cat $domain/recon.txt | nuclei -t /home/cyberhunter/nuclei-templates/exposed-panels/ -c 100 -iserver $interact -o $domain/recon/nuclei/exposed-panels.txt
    cat $domain/recon.txt | nuclei -t /home/cyberhunter/nuclei-templates/cnvd/ -c 100 -iserver $interact -o $domain/recon/nuclei/cnvd.txt
    cat $domain/recon.txt | nuclei -t /home/cyberhunter/nuclei-templates/default-logins/ -c 100 -iserver $interact -o $domain/recon/nuclei/default-logins.txt
    cat $domain/recon.txt | nuclei -t /home/cyberhunter/nuclei-templates/takeovers/ -c 100 -iserver $interact -o $domain/recon/nuclei/takeovers.txt
    cat $domain/recon.txt | nuclei -t /home/cyberhunter/nuclei-templates/token-spray/ -c 100 -iserver $interact -o $domain/recon/nuclei/token-spray.txt
    cat $domain/recon.txt | nuclei -t /home/cyberhunter/nuclei-templates/workflows/ -c 100 -iserver $interact -o $domain/recon/nuclei/workflows.txt
}
    echo "execute Nuclei ..." && scanner
else
    exit 0
fi

