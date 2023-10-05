# **Nextcloud BorgBackup**

This repository contains a Bash script for backup Nextcloud data and its database using BorgBackup.

## **Prerequisites**

- A running Nextcloud server
- Root access to the server

## **Getting Started**

### **Create Directories and Mount NAS**

Create the required directories for backup and restoration:

```
mkdir -p /backup/data /backup/temp /restore
```

### **Install BorgBackup**

Install BorgBackup using the following command:

```
apt install -y borgbackup
```

### 

### **Initialize Backup Repository**

Initialize the Borg repository:

```
borg init -e repokey-blake2 /backup/data/
```

### 

### **Configure Backup Script**

Copy the backup script `backup.sh` to the `/root/borgbackup/` directory and make it executable:

```
nano /root/borgbackup/backup.sh # Paste the script content here
chmod +x /root/borgbackup/backup.sh
```

Fill the `.env` file with the appropriate configuration variables

```
nano /root/borgbackup/.env
```

### **Security Note**

Ensure that the permissions of the `.env` file are restricted to prevent unauthorized access. You can set the file permissions using:

```
chmod 600 /root/borgbackup/.env
```

### **Automate with Cron**

Add a cron job to run the script automatically. For example, to start the backup daily at 03:00:

```
crontab -e
```

Add the following line:

```
0 3 * * * /root/borgbackup/backup.sh > /dev/null 2>&1 # This suppresses any output and error messages
```

### 

## **Usage**

### **List Backups**

To list existing backups, use:

```
borg list /backup/data
```

### 

### **Mount Backup for Browsing**

To mount a backup and browse its content:

```
borg mount /backup/data::<date> /restore/
```

### 

Example:

```
borg mount /backup/data::20230707_070011 /restore/
```

### 

### **Unmount Backup**

To unmount the backup:

```
borg umount /restore/
```

### 

## **License**

This project is under the MIT License.
