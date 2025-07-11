#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

echo "Updating packages..."
sudo apt update -y

echo "Installing Java (OpenJDK 21) and fontconfig..."
sudo apt install -y fontconfig openjdk-21-jre

echo "Verifying Java installation..."
java -version

echo "Adding Jenkins GPG key..."
sudo mkdir -p /etc/apt/keyrings
sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key

echo "Adding Jenkins repository..."
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

echo "Updating package list after adding Jenkins repo..."
sudo apt update -y

echo "Installing Jenkins..."
sudo apt install -y jenkins

echo "Starting and enabling Jenkins service..."
sudo systemctl start jenkins.service
sudo systemctl enable jenkins.service

 echo "Installation completed successfully!"