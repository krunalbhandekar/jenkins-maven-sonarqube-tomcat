# 🛠️ CI/CD Setup with Jenkins, SonarQube, Maven, Tomcat, and AWS S3

**Using Ubuntu EC2 Instances (Step-by-step guide)**

This guide walks you through setting up a CI/CD pipeline using **Jenkins, SonarQube, Maven, Tomcat**, and **AWS S3**, all on **Ubuntu-based EC2 instances**.

---

## 📦 Infrastructure Requirements

**💡 Create 3 AWS EC2 Instances:**

| Instance Name   | Type      | Storage | Purpose                        |
| --------------- | --------- | ------- | ------------------------------ |
| Jenkins Master  | t2.micro  | 15GB    | Jenkins + Java 21              |
| Maven-SonarQube | t2.medium | 15GB    | Maven + SonarQube + PostgreSQL |
| Tomcat Server   | t2.micro  | <15GB   | Tomcat 9                       |

**🔐 Security Group Ports:**

Ensure the following ports are open:

- **`22`** - SSH
- **`80`** - HTTP
- **`443`** - HTTPS
- **`8080`** - Jenkins & Tomcat
- **`9000`** - SonarQube

---

## ⚙️ Jenkins Master Setup

### 1. SSH into Jenkins Master

```bash
ssh -i <your-key>.pem ubuntu@<jenkins-master-public-ip>
sudo -i
```

### 2. Install Java 21 and Jenkins

```bash
sudo apt update -y
sudo apt install -y fontconfig openjdk-21-jre
java -version
```

```bash
sudo mkdir -p /etc/apt/keyrings
sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
```

```bash
sudo apt update -y
sudo apt install -y jenkins
sudo systemctl start jenkins.service
sudo systemctl enable jenkins.service
```

### 3. Access Jenkins Dashboard

Visit `http://<jenkins-public-ip>:8080`

```bash
cat /var/lib/jenkins/secrets/initialAdminPassword
```

🔑 Use the output above to unlock Jenkins.

👉 Install these plugins:

- **Deploy to Container**
- **SonarQube Scanner**
- **Sonar Quality Gates**
- **SSH Agent**
- **Pipeline Stage View**
- **AWS Credentials**

---

## 🧪 Maven & SonarQube Server Setup

### 1. SSH into Maven-SonarQube Instance

```bash
ssh -i <your-key>.pem ubuntu@<maven-sonar-public-ip>
sudo -i
```

### 2. Install Java 17, Maven, PostgreSQL, and SonarQube

```bash
apt update && apt upgrade -y
apt install -y openjdk-17-jdk unzip wget curl gnupg2 software-properties-common postgresql postgresql-contrib
```

### 3. Create SonarQube User and Download

```bash
adduser --system --no-create-home --group --disabled-login sonarqube
cd /opt
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-25.6.0.109173.zip
unzip sonarqube-25.6.0.109173.zip
mv sonarqube-25.6.0.109173 sonarqube
chown -R sonarqube:sonarqube /opt/sonarqube
```

### 4. Configure SonarQube

Edit **`/opt/sonarqube/conf/sonar.properties`**:

```bash
cat >> /opt/sonarqube/conf/sonar.properties <<EOF
sonar.web.port=9000
sonar.jdbc.username=sonar
sonar.jdbc.password=StrongPassword123
sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube
EOF
```

### 5. PostgreSQL DB Setup

```bash
sudo -u postgres psql <<EOF
CREATE USER sonar WITH ENCRYPTED PASSWORD 'StrongPassword123';
CREATE DATABASE sonarqube OWNER sonar;
ALTER ROLE sonar SET client_encoding TO 'UTF8';
ALTER ROLE sonar SET default_transaction_isolation TO 'read committed';
ALTER ROLE sonar SET timezone TO 'UTC';
EOF
```

### 6. Create SonarQube systemd service

```bash
cat > /etc/systemd/system/sonarqube.service <<EOF
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonarqube
Group=sonarqube
Restart=always
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF
```

```bash
systemctl daemon-reload
systemctl start sonarqube
systemctl enable sonarqube
```

### 7. Install Maven

```bash
cd /opt
sudo wget https://dlcdn.apache.org/maven/maven-3/3.9.10/binaries/apache-maven-3.9.10-bin.zip
sudo apt install -y unzip
sudo unzip apache-maven-3.9.10-bin.zip
sudo mv apache-maven-3.9.10 maven
```

Configure Maven path:

```bash
cat > /etc/profile.d/maven.sh <<EOF
export M2_HOME=/opt/maven
export PATH=\$M2_HOME/bin:\$PATH
EOF

sudo chmod +x /etc/profile.d/maven.sh
source /etc/profile.d/maven.sh
mvn -version
```

### 8. Access Jenkins Dashboard

Visit `http://<maven-sonarqube-public-ip>:9000`

- username - admin
- password - admin

---

## 🤝 Add Maven-SonarQube Node to Jenkins

Jenkins Dashboard → Manage Jenkins → Nodes → New Node

- Name: `maven-sonarqube`
- Type: Permanent Agent
- Remote root dir: `/home/ubuntu`
- Label: `maven-sonarqube`
- Usages: `only build jobs with label expressions matching this node`
- Launch method: `Launch agents via SSH`
  - Host: `<maven-sonarqube-public-ip>`
  - Credentials → add → jenkins
  - Kind: `ssh username with private key`
  - Enter id & Description
  - Username: `ec2-user` for linux server, `ubuntu` for ubuntu server
  - Choose private key → add
  - Enter your private key (`.pem`) content → add
- Select newly created Credential
- Host key verification strategy: `Non verifying verification strategy`
- Save

---

## 📊 SonarQube Project Creation

- Go to SonarQube Dashboard → Projects → Create Project → Local
- Set name, global settings → create Project
- Generate token
  - Open Project → locally
  - Check project name & expiry → generate (copy this project somewhere else)

---

## 🤝 Create connection between Jenkins & SonarQube

Jenkins Dashboard → Manage Jenkins → system

- Scroll till SonarQube servers
- Choose Environment variables → Add SonarQube
- Name: `sonar` (should be similar as SonarQube username)
- Server url: `http://<maven-sonarqube-public-ip>:9000`
- Server Authentication token → add → jenkins
  - Kind: `secret text`
  - Secret: `SonarQube token`
  - Id & Description: `sonar-cred`
- Select newly created token → apply → Save

---

## 🌐 Tomcat Server Setup

SSH into Tomcat instance:

```bash
ssh -i <your-key>.pem ubuntu@<tomcat-public-ip>
sudo -i
```

### 1. Install Java 21 and Tomcat 9

```bash
cd /opt
wget https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.107/bin/apache-tomcat-9.0.107.tar.gz
apt update -y
tar -xzvf apache-tomcat-9.0.107.tar.gz
apt install openjdk-21-jre
cd apache-tomcat-9.0.107/bin
./catalina.sh start
```

- Visit `<tomcat-public-ip>:8080`
- Click on Manager App → 403 Access Denied Error

### 2. Enable Manager Access

```bash
cd
cd /opt/apache-tomcat-9.0.107/conf/
vim tomcat-users.xml
```

Paste following lines at bottom (before `</tomcat-users>`)

```bash
<role rolename="manager-gui"/>
<role rolename="manager-jmx"/>
<role rolename="manager-script"/>
<role rolename="manager-status"/>
<user username="linux" password="linux" roles="manager-gui,manager-jmx,manager-script,manager-status"/>
```

```bash
cd
cd /opt/apache-tomcat-9.0.107/webapps/manager/META-INF
vim context.xml
```

Comment out:

```xml
<!-- <Valve className="org.apache.catalina.valves.RemoteAddrValve" ... /> -->
```

Restart Tomcat:

```bash
cd
cd /opt/apache-tomcat-9.0.107/bin/
./catalina.sh stop
./catalina.sh start
```

- Refresh the tomcat server and login
  - username: `linux`
  - password: `linux`

---

## 🚀 Jenkins Pipeline Configuration

Jenkins Dashboard → Create new item

- type: `Pipeline`
- Pipeline

```groovy
pipeline {
    agent { label 'maven-sonarqube' }

    stages {
        stage('Git Pull') {
            steps {
                git '<your-git-repo-url>'
            }
        }

        stage('build') {
            steps {
                sh '/opt/maven/bin/mvn clean package'
            }
        }

        stage('test') {
            steps {

            }
        }

        stage('deploy') {
            steps {

            }
        }

        stage('Artifact-s3') {
            steps {

            }
        }
    }
}
```

### Test Stage

- Click on Pipeline syntax
- Sample step → withSonarQubeEnv: Prepare sonarQube scanner environment
- Select available (sonar-cred) server authentication token
- Generate pipeline script → you will get

```groovy
withSonarQubeEnv(credentialsId: 'sonar-cred') {
    // some block
}
```

- Modify it to (here sonar is username)

```groovy
withSonarQubeEnv(installationName: 'sonar', credentialsId: 'sonar-cred') {
}
```

- Paste it in above pipeline under `test` stage step like:

```groovy
stage('test') {
            steps {
        withSonarQubeEnv(installationName: 'sonar', credentialsId: 'sonar-cred') {
        }
    }
}
```

### Build Stage

- Click on Pipeline syntax
- Sample step → deploy war/ear to a container
- WAR/EAR files → \*_/_.war
- Context path → /
- Click on add container → select our tomcat version (tomcat 9)
- Credentials → add → jenkins
- Username: `linux`
- Password: `linux`
- Id & Description: `tomcat` → Add
- Select newly created credential
- Tomcat url: `http://<tomcat-public-ip>:8080`
- Generate pipeline script → you will get

```groovy
deploy adapters: [tomcat9(alternativeDeploymentContext: '', credentialsId: 'tomcat', path: '', url: 'http://3.109.108.232:8080/')], contextPath: '/', war: '**/*.war'
```

- Paste it in above pipeline under `deploy` stage step like:

```groovy
stage('deploy') {
    steps {
        deploy adapters: [tomcat9(alternativeDeploymentContext: '', credentialsId: 'tomcat', path: '', url: 'http://3.109.108.232:8080/')], contextPath: '/', war: '**/*.war'
    }
}
```

### ☁️ Upload WAR to AWS S3

- Create aws s3 bucket
- SSH into maven-sonarqube instance:

```bash
sudo -i
cd /opt
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws configure
```

- Enter aws access key & secret key
- Check .war file path

```bash
cd
cd /home/ubuntu/workspace/<project-name>/target/
```

- Open jenkins project → Pipeline
- Click on Pipeline syntax
- Sample step → withCredentials: bind credentials to variables
- Bindings → add → aws key and secrets
- Credentials → add → jenkins
- Kind → aws credentials
- Id & Description → `aws-cred`
- Enter access key & secret key → Add
- Select newly added credentials
- Generate pipeline script → you will get

```groovy
withCredentials([aws(accessKeyVariable: 'AWS_ACCESS_KEY_ID', credentialsId: 'aws-cred', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY')]) {
    // some block
}
```

- Modify it to

```groovy
withCredentials([aws(accessKeyVariable: 'AWS_ACCESS_KEY_ID', credentialsId: 'aws-cred', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY')]) {
    sh 'aws s3 ls'
    sh 'aws s3 cp /home/ubuntu/workspace/<project-name>/target/<.war file name. ex:studentapp-2.2-SNAPSHOT.war> s3://<s3-bucket-name>'
}
```

- Paste it in above pipeline under `Artifact-s3` stage step like:

```groovy
stage('Artifact-s3') {
    steps {
        withCredentials([aws(accessKeyVariable: 'AWS_ACCESS_KEY_ID', credentialsId: 'aws-cred', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY')]) {
            sh 'aws s3 ls'
            sh 'aws s3 cp /home/ubuntu/workspace/<project-name>/target/<.war file name. eg:studentapp-2.2-SNAPSHOT.war> s3://<s3-bucket-name>'
        }
    }
}
```

---

## ✅ Testing

### Tomcat

```bash
http://<tomcat-public-ip>:8080
```

### SonarQube

SonarQube Dashboard → Projects

- Open project → locally → generate token → continue → Run analysis on your project → maven
- Copy the script

eg:

```bash
mvn clean verify sonar: sonar \
-Dsonar.projectKey=project1 \
-Dsonar.projectName='project1' \
-Dsonar.host.url=http://43.205.116.77:9000 \
-Dsonar.token=sqp_b6f2715dafb9c59089c2cc52534f9b8a60fd1c7d
```

- SSH into maven-sonarqube instance:

```bash
sudo -i
cd /home/ubuntu/workspace/<project-name>
ls
```

- Check `pom.xml` file is present or not:
- Paste the above script and enter
- Wait till build success
- Now go to sonarQube dashboard and open project, you will see the test-case/Quality overview

---

### 👨‍💻 Author

Maintained by **[Krunal Bhandekar](https://www.linkedin.com/in/krunal-bhandekar/)**

---
