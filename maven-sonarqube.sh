#!/bin/bash

# === Variables ===
SONAR_VERSION="25.6.0.109173"
SONAR_USER="sonarqube"
SONAR_DB_USER="sonar"
SONAR_DB_PASS="StrongPassword123"
SONAR_DB_NAME="sonarqube"
SONAR_DIR="/opt/sonarqube"
JAVA_PACKAGE="openjdk-17-jdk"

# === Update & Install Required Packages ===
apt update && apt upgrade -y
apt install -y $JAVA_PACKAGE unzip wget curl gnupg2 software-properties-common postgresql postgresql-contrib

# === Create SonarQube User ===
adduser --system --no-create-home --group --disabled-login $SONAR_USER

# === Download and Extract SonarQube ===
cd
cd /opt
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-$SONAR_VERSION.zip
unzip sonarqube-$SONAR_VERSION.zip
mv sonarqube-$SONAR_VERSION sonarqube
chown -R $SONAR_USER:$SONAR_USER $SONAR_DIR

# === Configure SonarQube ===
cat >> $SONAR_DIR/conf/sonar.properties <<EOF
sonar.web.port=9000
sonar.jdbc.username=$SONAR_DB_USER
sonar.jdbc.password=$SONAR_DB_PASS
sonar.jdbc.url=jdbc:postgresql://localhost/$SONAR_DB_NAME
EOF

# === Create PostgreSQL User and Database ===
sudo -u postgres psql <<EOF
CREATE USER $SONAR_DB_USER WITH ENCRYPTED PASSWORD '$SONAR_DB_PASS';
CREATE DATABASE $SONAR_DB_NAME OWNER $SONAR_DB_USER;
ALTER ROLE $SONAR_DB_USER SET client_encoding TO 'UTF8';
ALTER ROLE $SONAR_DB_USER SET default_transaction_isolation TO 'read committed';
ALTER ROLE $SONAR_DB_USER SET timezone TO 'UTC';
EOF

# === Create systemd Service File ===
cat > /etc/systemd/system/sonarqube.service <<EOF
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking
ExecStart=$SONAR_DIR/bin/linux-x86-64/sonar.sh start
ExecStop=$SONAR_DIR/bin/linux-x86-64/sonar.sh stop
User=$SONAR_USER
Group=$SONAR_USER
Restart=always
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF

# === Reload systemd, Enable and Start SonarQube ===
systemctl daemon-reload
systemctl enable sonarqube
systemctl start sonarqube

echo "Installing Maven..."
cd
cd /opt
sudo wget https://dlcdn.apache.org/maven/maven-3/3.9.10/binaries/apache-maven-3.9.10-bin.zip

echo "Installing unzip and extracting Maven..."
sudo apt install -y unzip
sudo unzip apache-maven-3.9.10-bin.zip
sudo mv apache-maven-3.9.10 maven

echo "Setting up Maven environment variables..."
sudo bash -c 'cat > /etc/profile.d/maven.sh <<EOF
export M2_HOME=/opt/maven
export PATH=\$M2_HOME/bin:\$PATH
EOF'

sudo chmod +x /etc/profile.d/maven.sh
source /etc/profile.d/maven.sh

echo "Verifying Maven installation..."
mvn -version

# === Display Public IP for Access ===
echo -e "\n✅ Maven & SonarQube installed successfully!"
echo "🌐 Access it at: http://$(curl -s ifconfig.me):9000"
echo "🔐 Default login: admin / admin"