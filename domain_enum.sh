#!/bin/bash

# variables
domain="$1"
wordlist="$2"
resolvers="resolvers.txt"
timestamp=$(date +%s)


# Help
if [ $# -lt 1 ]
then
    echo "Usage: $0 <DOMAIN> <WORDLIST>"
    exit 0
fi

if [ $# -lt 2 ]
then
   wordlist="n0kovo_small_dns.txt"
fi

read -p "User-Agent ?:" uagent

# Create structure & Download utils
mkdir -p $domain $domain/subdomains $domain/ip $domain/urls $domain/lists $domain/httpx
wget https://raw.githubusercontent.com/trickest/resolvers/main/resolvers.txt -O $domain/lists/resolvers.txt &&
wget https://github.com/n0kovo/n0kovo_subdomains/raw/main/n0kovo_subdomains_small.txt -O $domain/lists/n0kovo_small_dns.txt &&

# Process
echo "WordList: $wordlist"
echo -e "Processing...........please wait\n"

echo -e "execute SubFinder ...\n" &&
subfinder -d $domain -o $domain/subdomains/subfinder.txt &>/dev/null &&
sleep 5

echo -e "execute assetfinder ...\n" &&
assetfinder -subs-only $domain | tee $domain/subdomains/assetfinder.txt &>/dev/null &&
sleep 10

echo -e "execute Amass ...\n" &&
amass enum -passive -d $domain -max-dns-queries 100 -config ~/.config/amass/config.ini -o $domain/subdomains/amass.txt &>/dev/null &&
sleep 10

#echo -e "execute ShuffleDns ...\n" &&
#shuffledns -d $domain -w $domain/$wordlist -r $domain/$resolvers -wt 10 -retries 2 -t 2000 -o $domain/subdomains/shuffledns.txt 1&>/dev/null && 

cat $domain/subdomains/*.txt | sort -u > $domain/subdomains/all.txt &&

echo -e "Resolving DNS ..."
echo -e "execute massdns ...\n"
massdns -r $domain/lists/$resolvers -t A -o S $domain/subdomains/all.txt -w $domain/subdomains/massdns.txt &>/dev/null &&
sed 's/A.*//' $domain/subdomains/massdns.txt | sed 's/CN.*//' | sed 's/\..$//' > $domain/subdomains/all_resolved.txt &&
sleep 10
echo -e "execute shuffledns ...\n"
shuffledns -l $domain/subdomains/all.txt -r $domain/lists/$resolvers -wt 10 | anew -q $domain/subdomains/all_resolved.txt &&
sleep 10

#echo -e "Execute port scanning via DNS record A ...\n"
#cat $domain/subdomains/all_resolved.txt | sort -u | naabu -silent -c 20 -rate 750 | tee $domain/ip/ports_scan.txt &>/dev/null &&

echo -e "Execute httpx for alives hosts ...\n"
#echo -e "For IP ...\n"
#cat $domain/ip/ports_scan.txt | httpx -silent -H "User-Agent:$uagent" -threads 45 -rate-limit 80 -o $domain/httpx/naabu_alives.txt
echo -e "For all subs ...\n"
cat $domain/subdomains/all.txt | httpx -silent -H "User-Agent:$uagent" -threads 45 -rate-limit 80 -o $domain/httpx/all_alives.txt &>/dev/null &&
sleep 5
echo -e "For internal hosts ...\n"
myInternSubs $domain/subdomains/all.txt &>/dev/null &&
mv internal_subs.txt $domain/subdomains/internal_subs.txt &&
cat $domain/subdomains/internal_subs.txt | httpx -silent -title -sc -ct -web-server -td -follow-redirects -fc 502 -H "User-Agent:$uagent" -p 80,443,81,8080,8008,8000,8443,3000,3333,3443 -threads 50 -rate-limit 80 -o $domain/httpx/internal_alives.txt &&
sleep 5
echo -e "For all resolved ...\n"
cat $domain/subdomains/all_resolved.txt | httpx -silent -title -sc -ct -web-server -td -follow-redirects -fc 502 -H "User-Agent:$uagent" -threads 50 -rate-limit 80 -o $domain/httpx/httpx-out_all-resolved.txt


# calculate duration process
end_time=$(date +%s)
seconds=$(expr $end_time - $timestamp)
time=""

if [[ $seconds -gt 59 ]]
then
    minutes=$(expr $seconds / 60)
    time="$minutes minutes"
else
    time="$seconds seconds"
fi

echo "process duration: $time"

