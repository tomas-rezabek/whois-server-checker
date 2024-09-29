\
#!/bin/bash

#Udaje Ceskeho hostingu
ch_registrator="REG-THINLINE"
ch_nameservery=("ns1.thinline.cz." "ns2.thinline.cz." "ns3.cesky-hosting.eu.")
ch_wildcard="91.239.200." #wildcard pattern
ch_ipv6_wildcard="2001:67c:e94:0:1:5bef:"
ch_mx=("mx1a10.thinline.cz." "mx1b10.thinline.cz." "mx1c10.thinline.cz." "mx1d10.thinline.cz." "mx1a20.thinline.cz." "mx1b20.thinline.cz." "mx1c20.thinline.cz.")
domain=$1
LOG=$2
# Check if the log file path is provided, else use a default
if [ -z "$LOG" ]; then
    LOG='./logs/check.log'
fi

highlight_if_match() {
   local value=$(echo "$1" | xargs)
   local expected=$(echo "$2" | xargs)
   local wildcard=$3

   if [[ "$value" == "$expected" ]]; then
	echo -e "<span class="green">$value</span>"
   else
	echo -e "<span class="red">$value</span>" # red if not match, cizi
   fi
}

# Function to fetch Whois info (registrant, expiration date, etc.)
fetch_whois() {
    cat<<EOF
    <h2>Vysvětlivka</h2>
    <p>Všechny <span class="green">ZELENÉ</span> hodnoty patří Českému hostingu a všechny <span class="red">ČERVENÉ</span> jsou cizí.</p>
    <h3>Výsledek pro doménu: <span class="yellow"><strong>$domain</strong></span></h3>
EOF

    retries=6 # počet pokusů
    delay=6   # delay čekání

    for ((i=1; i<=retries; i++)); do
        # Fetch whois data
        whois_data=$(proxychains whois "$domain")

        # Check for connection limit exceeded
        if echo "$whois_data" | grep -q "Your connection limit exceeded"; then
            echo -e "<small class="pokusy">Počet WHOIS pokusů: #$i</small>"
            for ((d=delay; d>=0; d--)); do
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
                    expiraceStatus=" - <span class="red">DOMENA JE PO EXPIRACI</span>"
                elif [[ $brzyExpiruje == true ]]; then
                    expiraceStatus=" - <span class="red">BRZY EXPIRUJE</span>"
                else
                    expiraceStatus="- <span class="green">OK</span>"
                fi

                if [[ $dnssec == "" ]]; then
                    dnssec="OFF"
                else
                    dnssec="<span class="green">ON</span>"
                fi

                # Output HTML
cat <<EOF
    <div class="container">
        <div class="row">
            <div class="col-sm">
                <p><strong>TLD domény:</strong> $tld</p>
                <p><strong>DNSSEC:</strong> $dnssec</p>
                <p><strong>Vlastník domény:</strong> $vlastnik</p>
                <p><strong>Registrátor kontaktu:</strong> $registratorKontaktu</p>
                <p><strong>Jméno a příjmení vlastníka:</strong> $jmenoVlastnika</p>
                <p><strong>Registrátor domény:</strong> $(highlight_if_match "$registrator" "$ch_registrator")</p>
                <p><strong>Registrováno:</strong> $registrovano</p>
                <p><strong>Expiruje:</strong> $expiruje $expiraceStatus</p>
            </div>

EOF


            elif [[ "$tld" == "com" ]]; then
                # Extract the relevant information
                registrator=$(echo "$whois_data" | grep -iE 'Registrant Name' | head -n 1 | sed 's/Registrant Name: *//I')
                registrovano=$(echo "$whois_data" | grep -iE 'Creation Date' | head -n 1 | sed 's/Creation Date: *//I')
                expiruje=$(echo "$whois_data" | grep -iE 'Registrar Registration Expiration Date' | head -n 1 | sed 's/Registrar Registration Expiration Date: *//I')
                dnssec=$(echo "$whois_data" | grep -iE 'DNSSEC' | head -n 1 | sed 's/DNSSEC: *//I' | xargs)
                statusDomeny=$(echo "$whois_data" | grep -iE 'Domain Status' | head -n 1 | sed 's/Domain Status: *//I' | xargs)

				if [[ "$statusDomeny" == *"clientTransferProhibited"* ]]; then
					statusDomeny=" <span class="red">Doménu nelze převést</span>"
				elif [[ "$statusDomeny" == *"clientRenewProhibited"* ]]; then
					statusDomeny=" <span class="red">Doménu nelze prodloužit</span>"
				elif [[ "$statusDomeny" == *"ok"* ]]; then
					statusDomeny=" <span class="green">Doménu lze převést</span>"
				else
					statusDomeny=" <span class="red">Status se nepodařilo zjistit.</span>"
				fi

                echo -e "TLD domény: $tld"
			elif [[ $"$tld" == "eu" ]]; then
                echo -e "TLD domény: $tld"
            else
                echo -e "Tahle koncovka není podporována pro whois informace."
            fi

            # Exit the loop since the WHOIS data was successfully fetched
            return 0
        fi
            # Check if it's the last retry
        if [ "$i" -eq "$retries" ]; then
        echo -e "WHOIS selhal již $retries pokusů, skript se ukončí."
        exit 1  # Exit with a non-zero status to indicate failure
        fi
    done
}

# Function to fetch Nameservers
fetch_nameservers() {
    echo -e "<div class="col-sm"><h3>Nameservery:</h3>"
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
	echo -e "<p class="green">$ns</p>"
   else
	echo -e "<p class="red">$ns</p>"
   fi
 done
}

# Function to fetch A records
fetch_a_records() {
    echo -e "<h3>A Záznamy:</h3>"
    a_records=$(host -t a $domain | grep "has address" | awk '{print $4}')
	for ip in $a_records; do
		if [[ "$ip" == "$ch_wildcard"* ]]; then
			whois_a_record=$(whois $ip)
			vlastnik=$(echo "$whois_a_record" | grep -iE 'org-name' | head -n 1 | sed 's/org-name: *//I')
			echo -e "<p class="green">$ip</p>"
		else
			whois_a_record=$(whois $ip)
			vlastnik=$(echo "$whois_a_record" | grep -iE 'org-name' | head -n 1 | sed 's/org-name: *//I')
			echo -e "<p class="red">$ip ($vlastnik)</p>"
		fi

       done
}

fetch_aaaa_records() {
    echo -e "<h3>AAAA Záznamy (IPv6):</h3>"
    aaaa_records=$(host -t aaaa $domain | grep "has IPv6 address" | awk '{print $5}' | xargs)
	for ipv6 in $aaaa_records; do
		if [[ "$ipv6" == "$ch_ipv6_wildcard"* ]]; then
			echo -e "<p class="green">$ipv6</p>"
		else
			echo -e "<p class="red">$ipv6</p>"
		fi
	done
}

fetch_txt_records() {
    echo -e "</div><div class="col-sm"><h3>TXT Záznamy:</h3>"
    dig txt $domain +short | while IFS= read -r line; do
        echo -e "<p>$line</p>\n"
    done
}

# Function to fetch MX records
fetch_mx_records() {
    echo -e "<h3>MX Záznamy (Pošta):</h3>"
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
			echo -e "<p class="green">$mx</p>"
		else
			echo -e "<p class="red">$mx</p>"
		fi
	done
	echo -e "</div></div>"
}

# Fetch information
fetch_whois > $LOG
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
