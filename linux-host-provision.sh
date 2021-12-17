
set -x
source /tmp/provinfo.sh
export DEBIAN_FRONTEND=noninteractive
sudo bash -c "echo ${WIN1} win1 >> /etc/hosts"
cat /etc/hosts
sudo apt-get update -y > /tmp/prov.log
sudo apt-get upgrade -y >> /tmp/prov.log
sudo apt-get install -y ansible freerdp2-x11 >> /tmp/prov.log
sudo nohup bash -c 'sleep 1; shutdown -r now' &
