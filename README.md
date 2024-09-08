# A System Setup Script
This will:
1. Add a new user with the specified username.
2. Optionally copy the .ssh folder to the new user's home directory and set correct permissions.
3. Add the new user to the sudo group.
4. Optionally Install Docker and Docker Compose, and add the new user to the Docker group.
5. Optionally Ensure that the correct version of Docker is installed based on your operating system.

# Important Note
As you always should please look over the script before running. It is safe to run but it is good practice to do so.

# Instructions
Logged in as 'Root' user
```
wget https://raw.githubusercontent.com/WilliamUK17/new-system-script/main/script.sh
chmod +x script.sh
./script.sh
```
Non-Root User
```
wget https://raw.githubusercontent.com/WilliamUK17/new-system-script/main/script.sh
chmod +x script.sh
sudo ./script.sh
```
If you get a error saying wget is not installed you need to install this with your package manager for example for debian:
```
sudo apt install wget
```
