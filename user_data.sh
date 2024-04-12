    #! /bin/bash
    apt-get update
    apt-get install apache2 -y
    systemctl start apache2
    systemctl enable apache2
    echo "<h1>Apache Web Test on Server 01</h1>" > /var/www/html/index.html