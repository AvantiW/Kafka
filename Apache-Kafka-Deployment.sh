#################################
	    Kafka Deployment
#################################


## First we will setup Zookeeper Quorum


-----**** Update and install necessary packages ****-----

sudo apt-get update && sudo apt-get -y install ca-certificates zip net-tools netcat

-----**** Install java ****-----

sudo apt install openjdk-8-jdk openjdk-8-jre -y
java -version

-----**** Send key to DC ****-----

scp -i abc.pem abc.pem ubuntu@oub-ip:~/.ssh/

-----**** Configure profile ****-----

nano .profile

eval `ssh-agent` ssh-add /home/ubuntu/.ssh/as-key.pem

source .profile

-----**** Set swappiness ****-----

sudo sysctl vm.swappiness=1
echo 'vm.swappiness=1' | sudo tee --append /etc/sysctl.conf

-----**** Download zookeeper and kafka ****-----

wget https://archive.apache.org/dist/kafka/0.10.2.1/kafka_2.12-0.10.2.1.tgz

tar -xzvf kafka_2.12-0.10.2.1.tgz

sudo mv kafka_2.12-0.10.2.1 /usr/local/kafka

sudo chown ubuntu:ubuntu -R /usr/local/kafka/

-----**** Configure environment variable ****-----

nano .bashrc

export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export KAFKA_HOME=/usr/local/kafka
export PATH=$PATH:$KAFKA_HOME/bin
export PATH=$PATH:$KAFKA_HOME/config
export PATH=$PATH:/usr/local/kafka/bin/
export PATH=$PATH:/usr/local/kafka/config/

source .bashrc

-----**** zookeeper quickstart ****-----

zookeeper-server-start.sh $KAFKA_HOME/config/zookeeper.properties

-----**** Testing zookeeper install ****-----

zookeeper-server-start.sh -daemon /usr/local/kafka/config/zookeeper.properties

zookeeper-shell.sh localhost:2181

ls /

ctrl+c

echo "ruok" | nc localhost 2181 ; echo

-----**** Configure zookeeper bootscripts ****-----

sudo nano /etc/init.d/zookeeper

sudo chown root:root /etc/init.d/zookeeper

sudo chmod +x /etc/init.d/zookeeper

sudo update-rc.d zookeeper defaults

## Now you can use service command for zookeeper

$ sudo service zookeeper stop

$ sudo service zookeeper start

## Check whether it started

nc -vz localhost 2181

echo "ruok" | nc localhost 2181 ; echo



###### Create an Image at this point and launch 2 more instances from this ami


-----**** Configure hosts ****-----

sudo nano /etc/hosts

172.31.81.58 ip-172-31-81-58.ec2.internal zk1
172.31.81.58 ip-172-31-81-58.ec2.internal kf1
172.31.90.58 ip-172-31-90-58.ec2.internal zk2
172.31.90.58 ip-172-31-90-58.ec2.internal kf2
172.31.84.245 ip-172-31-84-245.ec2.internal zk3
172.31.84.245 ip-172-31-84-245.ec2.internal kf3

## Do this on all 3 nodes

-----**** Install dsh ****-----

sudo apt-get install dsh -y

sudo nano /etc/dsh/machines.list
#localhost
zk1
zk2
zk3

dsh -a uptime

-----**** Start zookeeper on all nodes and check connectivity ****-----

dsh -a sudo service zookeeper start

nc -vz zk2 2181
nc -vz zk3 2181

ssh zk2
nc -vz zk1 2181
exit

## stop zookeeper server
dsh -a sudo service zookeeper stop

-----**** Create data dictionary for zookeeper****-----

dsh -a sudo mkdir -p /data/zookeeper

dsh -a sudo chown -R ubuntu:ubuntu /data/zookeeper/

-----**** create server identity****-----

echo "1" > /data/zookeeper/myid
cat /data/zookeeper/myid 

ssh zk2
echo "2" > /data/zookeeper/myid
exit

ssh zk3
echo "3" > /data/zookeeper/myid
exit

dsh -a cat /data/zookeeper/myid 

-----**** Configure zookeeper settings****-----

dsh -a rm /usr/local/kafka/config/zookeeper.properties

nano /usr/local/kafka/config/zookeeper.properties
## copy contents from file

scp /usr/local/kafka/config/zookeeper.properties zk2:/usr/local/kafka/config/

scp /usr/local/kafka/config/zookeeper.properties zk3:/usr/local/kafka/config/

-----**** Start the zookeeper service ****-----

dsh -a sudo service zookeeper start

## verify whether started 

echo "ruok" | nc zk1 2181 ; echo
echo "ruok" | nc zk2 2181 ; echo
echo "ruok" | nc zk3 2181 ; echo

echo "stat" | nc zk1 2181 ; echo
echo "stat" | nc zk2 2181 ; echo
echo "stat" | nc zk3 2181 ; echo


############### Kafka Deployment ##################


-----**** Creating and attaching volumes ****-----

## Create 3 volumes and attach to instances

dsh -a sudo lsblk

dsh -a sudo file -s /dev/xvdf   

dsh -a sudo apt-get install xfsprogs

dsh -a sudo mkfs -t xfs /dev/xvdf 

dsh -a sudo mkdir /data/kafka

dsh -a sudo mount /dev/xvdf /data/kafka 

dsh -a sudo lsblk

df -h /data/kafka

## Making EBS automount on reboot

dsh -a sudo cp /etc/fstab /etc/fstab.bak

sudo su
echo '/dev/xvdf /data/kafka xfs defaults 0 0' >> /etc/fstab
exit

ssh zk2 
sudo su
echo '/dev/xvdf /data/kafka xfs defaults 0 0' >> /etc/fstab
exit

ssh zk3
sudo su
echo '/dev/xvdf /data/kafka xfs defaults 0 0' >> /etc/fstab
exit

dsh -a sudo cat /etc/fstab

## Reboot instances from console

dsh -a sudo lsblk


## Start zookeeper service 

dsh -a sudo service zookeeper start


-----**** Configuring system to open 100000 files ****----

echo "* hard nofile 100000
* soft nofile 100000" | sudo tee --append /etc/security/limits.conf


ssh zk2
echo "* hard nofile 100000
* soft nofile 100000" | sudo tee --append /etc/security/limits.conf
exit

ssh zk3
echo "* hard nofile 100000
* soft nofile 100000" | sudo tee --append /etc/security/limits.conf
exit

## Reboot instances from console

##

dsh -a sudo chown -R ubuntu:ubuntu /data/kafka

dsh -a sudo service zookeeper start


------**** Configure kafka properties ****-----

dsh -a rm /usr/local/kafka/config/server.properties 

nano /usr/local/kafka/config/server.properties
## copy contents from file

ssh zk2
nano /usr/local/kafka/config/server.properties
## copy contents from file (Make necessary changes)

ssh zk3
nano /usr/local/kafka/config/server.properties
## copy contents from file (Make necessary changes)


-----**** Configure kafka bootscripts ****-----

sudo nano /etc/init.d/kafka

sudo chmod +x /etc/init.d/kafka

sudo chown root:root /etc/init.d/kafka 

sudo update-rc.d kafka defaults

## Do this on other two nodes

ssh zk2
sudo nano /etc/init.d/kafka
sudo chmod +x /etc/init.d/kafka
sudo chown root:root /etc/init.d/kafka 
sudo update-rc.d kafka defaults

ssh zk3
sudo nano /etc/init.d/kafka
sudo chmod +x /etc/init.d/kafka
sudo chown root:root /etc/init.d/kafka 
sudo update-rc.d kafka defaults


-----**** Start kafka service ****-----

dsh -a sudo service kafka start

nc -vz kf2 9092
nc -vz kf3 9092

## Check logs

tail -f /usr/local/kafka/logs/server.log 

ssh zk2 
tail -f /usr/local/kafka/logs/server.log 

ssh zk3
tail -f /usr/local/kafka/logs/server.log 


-----**** Working with kafka ****-----

## Create a topic

kafka-topics.sh --zookeeper zk1:2181,zk2:2181,zk3:2181/kafka --create --topic my-topic --replication-factor 3 --partitions 3 

## Create a producer

kafka-console-producer.sh --broker-list kf1:9092,kf2:9092,kf3:9092 --topic my-topic 
(publish some data)

## Create a consumer

kafka-console-consumer.sh --bootstrap-server kf1:9092,kf2:9092,kf3:9092 --topic my-topic --from-beginning

## Create another topic

kafka-topics.sh --zookeeper zk1:2181,zk2:2181,zk3:2181/kafka --create --topic my-topic2 --replication-factor 3 --partitions 3 

## List topics 

kafka-topics.sh --zookeeper zk1:2181,zk2:2181,zk3:2181/kafka --list
