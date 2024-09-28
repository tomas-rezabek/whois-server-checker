#!/bin/bash
LOG='/var/www/html/checker/logs/check.log'
. /var/www/html/checker/config/domena.cfg

# Color variables
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
LBLUE='\033[01;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

#Udaje Ceskeho hostingu
ch_registrator="REG-THINLINE"
ch_nameservery=("ns1.thinline.cz." "ns2.thinline.cz." "ns3.cesky-hosting.eu.")
ch_wildcard="91.239.200." #wildcard pattern
ch_ipv6_wildcard="2001:67c:e94:0:1:5bef:"
ch_mx=("mx1a10.thinline.cz." "mx1b10.thinline.cz." "mx1c10.thinline.cz." "mx1d10.thinline.cz." "mx1a20.thinline.cz." "mx1b20.thinline.cz." "mx1c20.thinline.cz.")
domain=$DOMENA


highlight_if_match() {
   local value=$(echo "$1" | xargs)
   local expected=$(echo "$2" | xargs)
   local wildcard=$3

   if [[ "$value" == "$expected" ]]; then
	echo -e "${GREEN}$value${NC}"
   else
	echo -e "${RED}$value${NC}" # red if not match, cizi
   fi
}

# Function to fetch Whois info (registrant, expiration date, etc.)
fetch_whois() {
	echo -e "${YELLOW} === Vysvětlivka === "
	echo -e "Všechny ${GREEN}ZELENÉ ${YELLOW}hodnoty patří Českému hostingu a všechny ${RED}ČERVENÉ ${YELLOW}jsou cizí."
    echo -e "Blízká expirace se kontroluje v následujících 14ti dnech."
    echo -e "${LBLUE}WHOIS data pro doménu: ${domain}${NC}"
    retries=5 # počet pokusů
    delay=7   # delay čekání

    for ((i=1; i<=retries; i++)); do
        # Fetch whois data
        whois_data=$(whois "$domain")

        # Check for connection limit exceeded
        if echo "$whois_data" | grep -q "Your connection limit exceeded"; then
            echo -e "${RED}WHOIS limit, zkusím to znovu za $delay vteřin${NC}"
            for ((d=delay; d>=0; d--)); do
                echo "$d"
                sleep 1
            done
        else
            # Extract the TLD
            tld="${domain##*.}"

            if [[ "$tld" == "cz" ]]; then
                # Extract the relevant information
                vlastnik=$(echo "$whois_data" | grep -iE 'registrant' | head -n 1 | sed 's/registrant: *//I')
                registratorKontaktu=$(echo "$whois_data" | awk '/contact:/,EOF' | grep -iE 'registrar' | head -n 1 | sed 's/registrar: *//I')
                jmenoVlastnika=$(echo "$whois_data" | grep -iE 'name:' | head -n 1 | sed 's/name: *//I')
                registrator=$(echo "$whois_data" | grep -iE 'registrar' | head -n 1 | sed 's/registrar: *//I')
                registrovano=$(echo "$whois_data" | grep -iE 'registered' | head -n 1 | sed 's/registered: *//I')
                dnssec=$(echo "$whois_data" | grep -iE 'keyset' | head -n 1 | sed 's/keyset: *//I')
                expirujeDatum=$(echo "$whois_data" | grep -iE '^.*expire:' | head -n 1 | sed 's/expire: *//I' | awk -F. '{print $3"-"$2"-"$1}')
                expiruje=$(echo "$whois_data" | grep -iE '^.*expire:' | head -n 1 | sed 's/expire: *//I')
                dnesniDatum=$(date +"%s")
                blizkaExpirace=$((dnesniDatum + 14 * 24 * 60 * 60)) # 14 dnu

                statusDomeny=$(echo "$whois_data" | grep -iE '^\s*status:' | head -n 1 | sed 's/^\s*status:\s*//I' | tr -d '\n' | xargs)
                expirujeVteriny=$(date -d "$expirujeDatum" +"%s")
                if [[ $expirujeVteriny -le $blizkaExpirace && $expirujeVteriny -gt $dnesniDatum ]]; then
                    brzyExpiruje=true
                else
                    brzyExpiruje=false
                fi

                if [[ $statusDomeny == "Expired" ]]; then
                    expiraceStatus="${RED} - DOMENA JE PO EXPIRACI"
                elif [[ $brzyExpiruje == true ]]; then
                    expiraceStatus="${RED} - BRZY EXPIRUJE"
                else
                    expiraceStatus="${GREEN} - OK"
                fi

                if [[ $dnssec == "" ]]; then
                    dnssec="${NC}OFF"
                else
                    dnssec="${GREEN}ON"
                fi

                # Output the results
                echo -e "${YELLOW}TLD domény:${NC} $tld"
                echo -e "${YELLOW}DNSSEC: ${NC}$dnssec"
                echo -e "${YELLOW}Vlastník domény: ${NC}$vlastnik"
                echo -e "${YELLOW}Registrátor kontaktu: ${NC}$registratorKontaktu"
                echo -e "${YELLOW}Jméno a příjmení vlastníka: ${NC}$jmenoVlastnika"
                echo -e "${YELLOW}Registrátor domény: ${NC}$(highlight_if_match "$registrator" "$ch_registrator")"
                echo -e "${YELLOW}Registrováno: ${NC}$registrovano"
                echo -e "${YELLOW}Expiruje: ${NC}$expiruje $expiraceStatus"

            elif [[ "$tld" == "com" ]]; then
                # Extract the relevant information
                registrator=$(echo "$whois_data" | grep -iE 'Registrant Name' | head -n 1 | sed 's/Registrant Name: *//I')
                registrovano=$(echo "$whois_data" | grep -iE 'Creation Date' | head -n 1 | sed 's/Creation Date: *//I')
                expiruje=$(echo "$whois_data" | grep -iE 'Registrar Registration Expiration Date' | head -n 1 | sed 's/Registrar Registration Expiration Date: *//I')
                dnssec=$(echo "$whois_data" | grep -iE 'DNSSEC' | head -n 1 | sed 's/DNSSEC: *//I' | xargs)
                statusDomeny=$(echo "$whois_data" | grep -iE 'Domain Status' | head -n 1 | sed 's/Domain Status: *//I' | xargs)

				if [[ "$statusDomeny" == *"clientTransferProhibited"* ]]; then
					statusDomeny="${RED} Doménu nelze převést"
				elif [[ "$statusDomeny" == *"clientRenewProhibited"* ]]; then
					statusDomeny="${RED} Doménu nelze prodloužit"
				elif [[ "$statusDomeny" == *"ok"* ]]; then
					statusDomeny="${GREEN} Doménu lze převést"
				else
					statusDomeny="${RED} Status se nepodařilo zjistit."
				fi
				
                # Output the results
                echo -e "${YELLOW}TLD domény:${NC} $tld"
                echo -e "${YELLOW}Status domény:${NC} $statusDomeny"
                echo -e "${YELLOW}DNSSEC: ${NC}$dnssec"
                echo -e "${YELLOW}Registrátor domény: ${NC}$(highlight_if_match "$registrator" "$ch_registrator")"
                echo -e "${YELLOW}Registrováno: ${NC}$registrovano"
                echo -e "${YELLOW}Expiruje: ${NC}$expiruje"
			elif [[ $"$tld" == "eu" ]]; then
				# Extract the relevant information
				# .eu domeny nam reknou velky prd pres whois
                # Output the results
                echo -e "${YELLOW}TLD domény:${NC} $tld"
            else
                echo -e "${YELLOW}Tahle koncovka není podporována pro whois informace."
            fi

            # Exit the loop since the WHOIS data was successfully fetched
            return 0
        fi
    done

    # If retries exhausted, show failure message
    if [[ $i -eq retries ]]; then
        echo -e "${RED}WHOIS selhal již $retries pokusů, skript se ukončí.${NC}"
        return 1
    fi
}



# Function to fetch Nameservers
fetch_nameservers() {
    echo -e "${YELLOW}Nameservery:${NC}"
    ns_data=$(host -t ns $domain | awk '{print $4}' | xargs)
    for ns in $ns_data; do
	match_found=false
	for expected_ns in "${ch_nameservery[@]}"; do
	  if [[ "$ns" == "$expected_ns" ]]; then
	     match_found=true
	     break
     fi
   done

   if [[ $match_found == true ]]; then
	echo -e "${GREEN}$ns${NC}"
   else
	echo -e "${RED}$ns${NC}"
   fi
 done
}

# Function to fetch A records
fetch_a_records() {
    echo -e "${YELLOW}A Záznamy:${NC}"
    a_records=$(host -t a $domain | grep "has address" | awk '{print $4}')
	for ip in $a_records; do
		if [[ "$ip" == "$ch_wildcard"* ]]; then
			echo -e "${GREEN}$ip${NC}"
		else
			echo -e "${RED}$ip${NC}"
		fi

       done
}

fetch_aaaa_records() {
    echo -e "${YELLOW}AAAA Záznamy (IPv6):${NC}"
    aaaa_records=$(host -t aaaa $domain | grep "has IPv6 address" | awk '{print $5}' | xargs)
	for ipv6 in $aaaa_records; do
		if [[ "$ipv6" == "$ch_ipv6_wildcard"* ]]; then
			echo -e "${GREEN}$ipv6${NC}"
		else
			echo -e "${RED}$ipv6${NC}"
		fi
	done
}

fetch_txt_records() {
    echo -e "${YELLOW}TXT Záznamy:${NC}"
    dig txt $domain +short | while IFS= read -r line; do
        echo -e "$line\n"
    done
}

# Function to fetch MX records
fetch_mx_records() {
    echo -e "${YELLOW}MX Záznamy (Pošta):${NC}"
    mx_records=$(host -t mx $domain | awk '{print $7}')
	for mx in $mx_records; do
		match_found=false
		for expected_mx in "${ch_mx[@]}"; do
			if [[ "$mx" == "$expected_mx" ]]; then
				match_found=true
				break
			fi
		done

		if [[ $match_found == true ]]; then
			echo -e "${GREEN}$mx${NC}"
		else
			echo -e "${RED}$mx${NC}"
		fi
	done
}

# Fetch information
fetch_whois >> $LOG
echo ""
fetch_nameservers >> $LOG
echo ""
fetch_a_records >> $LOG
echo ""
fetch_aaaa_records >> $LOG
echo ""
fetch_txt_records >> $LOG
echo ""
fetch_mx_records >> $LOG

fi