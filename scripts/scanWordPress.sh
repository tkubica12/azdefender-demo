export name=web-5zfbmg5p6w444

sudo apt install nmap ruby -y
sudo nmap -O -sV -Pn -v --script=http-enum,vuln,http-vuln-cve2014-8877,http-vuln-cve2017-1001000,http-wordpress-enum,http-wordpress-users,http-wordpress-brute $name.azurewebsites.net

sudo apt install docker.io
sudo docker run -it --rm wpscanteam/wpscan --url https://$name.azurewebsites.net/