#!/bin/bash

## set working directory. 
function setD(){
	pushd .
}
## jump back to origin directory and rm script
function rmScript(){
    if [ "$wpUserSet" == true ]; then
        delNewWpUser;
    fi
	popd;
	rm $0;
}

#set -x
function wpScript(){
## get tempSiteID
tempSiteID=$(echo $HOME | awk -F"/" '{print $3}');

## set the dbHost back to internal-db.sxxxxxx.gridserver.com
siteID="internal-db.s${tempSiteID}.gridserver.com";

dbName=$(cat wp-config.php | grep "DB_NAME" | awk -F"'" '{print $4}')
dbUser=$(cat wp-config.php | grep "DB_USER" | awk -F"'" '{print $4}')
dbPass=$(cat wp-config.php | grep "DB_PASSWORD" | awk -F"'" '{print $4}')
dbHost=$(grep -P -io "(localhost(:3306|)|[$]_ENV{('|)DATABASE_SERVER('|)}|(int|ext)ernal-db.s${tempSiteID}.gridserver.com)" wp-config.php);

#####################################
###  Switch DB host in wp-config  ###
#####################################
function switchDB(){
	sed -i "/.*DB_HOST.*/c\define('DB_HOST','${siteID}');" ./wp-config.php;
}

#####################################
#####  Create phpinfo page    #######
#####################################
function phpInfo(){
		echo "<?php
	phpinfo();
?>" > ./phpinfo.php
}

######################################
### used to output current DB host ###
######################################
function databaseOutput(){
    ## create case statments
    case $dbHost in
        "localhost"|"localhost:3306") echo "DB_HOST is currently set as $dbHost. You should really change that."
            runMore=true;
    		while [ "$runMore" == true ]
    		do
    		   read -p "Would you like to switch it to ${siteID}: y\n?" switch;
    			if [ "$switch" == "y" ]; then
    				runMore=false;
    				switchDB;
    			elif [ "$switch" == "n" ]; then
    				printf "Ok, but it may not work properly.\n";
    				runMore=false;
    			else
    				printf "Please enter in a valid choice.";
    			fi
    		done;;
        "\$_ENV{DATABASE_SERVER}"|"\$_ENV{'DATABASE_SERVER'}"|"internal-db.s${tempSiteID}.gridserver.com"|"external-db.s${tempSiteID}.gridserver.com") echo "DB_HOST is currently set as $dbHost.";;
        "") echo "You may need to check your DB_HOST setting";;
    esac
}


### get the table prefix
prefix=$(grep "table_prefix" wp-config.php | awk -F"'" '{print $2}');
optionstable="options";

#display currently set creds
echo ---------------------------------------------------------
echo Current DB Name: $dbName 
echo ---------------------------------------------------------
echo Current DB User: $dbUser
echo ---------------------------------------------------------
echo Current DB Pass: $dbPass
echo ---------------------------------------------------------
echo Current DB Host: $dbHost
echo ---------------------------------------------------------
echo Current DB prefix: $prefix
echo ---------------------------------------------------------

databaseOutput;

########################################
#######   COMPARE NEW INPUT   ##########
########################################

function checkInput(){
    loopAgain=true;
	while [ "$loopAgain" == true ]
	do	
		if [ "$1" == "$2" ];
		then
			printf "\nBoth inputs match. New siteurl and home are set to $newURL\n";
			printf "You are sure you want to proceed? y/n:";
			read a;
				if [ "$a" == "y" ];
				then
					setURL $newURL $newHome;
					loopAgain=false;
				else
					getLocation;
				fi
		else
			printf "\nThe inputs do not match. Did you want to set\n";
			printf "siturl: $newURL\nhome: $newHome\n";
			printf "Are sure you want to proceed? y/n:";
			read a;
				if [ "$a" == "y" ];
				then
					setURL $newURL $newHome;
					loopAgain=false;
				else
					getLocation;
				fi
		fi
	done
}

########################################
#####  GET NEW SITEURL AND HOME  #######
########################################

function getLocation(){
    runagain=true;
    	while [ $runagain == true ]
    	do  
    		printf "Enter in the new siteurl:";
    		read siteurl;
            	if [[ "$siteurl" == https://* ]] || [[ "$siteurl" == http://* ]]; 
            	then
                	printf "Thank you\n";
                	newURL="${siteurl}";    
                	runagain=false;
                else
                	printf "ERROR! You need to start with http:// or https://\n";
                	runagain=true;
                fi  
    	done
    runmore=true;
    	while [ $runmore == true ]
    	do  
        	printf "\nEnter in the new home:";
            read home;
        		if [[ "$home" == https://* ]] || [[ "$home" == http://* ]]; 
                then    
                	printf "Thank you\n";
                    newHome="${home}"; 
                    runmore=false;
                else
                    printf "You need to start with http:// or https://\n";
                    runmore=true;
                fi  
    	done
    	checkInput $newURL $newHome;
}

########################################
#####  GET AND SET NEW WP PASS  ########
########################################

function setpass(){
    #display list of users and their ID's
    mysql -u $dbUser -h $siteID --password=$dbPass $dbName -e "SELECT ID, user_login, user_pass, user_status, display_name FROM ${prefix}users;"
    #while loop to run through menu
    editpass=true;
    while [ "$editpass" == true ]
    do
    	#ask if they want to edit password or exit
    	printf "Are you sure you want to set a new password? y/n: ";
    	read proceed;
    		if [ "$proceed" == "y" ];
    		then
    		## ask which ID they want to effect
    			valid=false
    			while [ "$valid" == false ]
    			do
    				printf "Enter in the ID number or q to quit: ";
    				read idNum;
    					if [ "$idNum" == "q" ];
    					then
    						break;
    					elif [ "$idNum" == "" ];
    					then
    						echo "You need to enter in a value";
    					elif [[ "$idNum" -gt "0" ]];
    					then
      						if [[ "$idNum" -lt "50" ]];
      						then
        						echo "number is valid";
    							valid=true;
      						else
        						echo "Enter in a valid number";
      						fi
    					else
      						echo "I think you need to try again.";
    					fi
    			done
    		## ask for the new password
    			goodPass=false
    				while [ "$goodPass" != true ]
    				do
    					printf "Enter in new password: ";
    					read newPass;
    						if [ "$newPass" == "" ];
    						then
    							echo "You need to enter in a value";
    						elif [ "$newPass" == "q" ];
    						then
    							editpass=false;
    							break;
    						else
    							goodPass=true;
    						fi
    					read -p "Enter in new password again: " verPass;
    						if [ "$verPass" == "$newPass" ];
    						then
    							echo "Values match";
    							#create hash from newPass
    							hash="$(echo -n "$newPass" | md5sum )"; hash="$(echo "$hash" | awk -F" " '{print $1}')";
    							#passHash=$(echo -n “$newPass” | md5sum | awk -F" " '{print $1}');
    							echo "${hash}....";
    							## enter in MySQL command
    							mysql -u $dbUser -h $siteID --password=$dbPass $dbName -e "UPDATE ${prefix}users SET user_pass='${hash}' where ID='$idNum';"
    							goodPass=true;
    							editpass=false;
    						else
    							echo "Passwords did not match. Try again:"
    							goodPass=false;
    						fi
    				done
    		elif [ "$proceed" == "" ];
    		then
    			echo "You need to enter in a response. Please try again: ";
    		else
    			echo "Back to main menu";
    			read -t 1 r;
    			editpass=false;
    		fi
    done
}

########################################
#########    SITE CLONE    #############
########################################
: ' function siteClone(){
    #let the user know that they need to set up a DB and dbUser first
    
    
    cat <<- _EOF_
    Would you like to clone your site to.
    a: subdomain (ex: dev.yourdomain.com)
    b: subdirectory (ex: yourdomain.com/subdirectory)
    _EOF_
    read -p "Please enter your selection: " cloneChoice;
    
    #let the user know they need to 
    
}'

########################################
#######  CREATE NEW WP USER  ###########
########################################
function newUser(){
    wpUserSet=true;
    loop2=true
        while [ ${loop2} == 'true' ];
        do
        #get the user's email address
            read -p "please enter in an email address for this user: " userSetEmail;
                case userSetEmail in
                    "") printf "Please try again\n";;
                    *) printf "Thank you.\n";
                       loop2=false;;
                esac
        done
    #create hash based off of current date 
    rand=`date|md5sum|md5sum`;
    newWpUser="${prefix}${rand:15:5}";
    mysql -u $dbUser -h $siteID --password=$dbPass $dbName -e "INSERT INTO ${prefix}users (user_login,user_pass,user_nicename,user_email,user_url,user_activation_key,user_status,display_name) VALUES ('${newWpUser}',MD5('${rand:5:10}'),'${newWpUser}','${userSetEmail}','','','0','Testing Account');INSERT INTO ${prefix}usermeta (user_id,meta_key,meta_value) VALUES ((SELECT ID FROM ${prefix}users WHERE user_login='${newWpUser}'),'${prefix}capabilities','a:1:{s:13:\"administrator\";b:1;}');INSERT INTO ${prefix}usermeta (user_id,meta_key,meta_value) VALUES ((SELECT ID FROM ${prefix}users WHERE user_login='${newWpUser}'),'${prefix}user_level','10');";
    
    #newWpUser="${prefix}${rand:15:5}";
    printf "\nSQL has been run, username is ${newWpUser} and password is ${rand:5:10}\n\n"; #Press enter to remove the user...\n";
    unset rand;
}

#delete the newly created user
function delNewWpUser(){
	mysql -u $dbUser -h $siteID --password=$dbPass $dbName -e "DELETE FROM ${prefix}usermeta WHERE user_id=(SELECT ID FROM ${prefix}users WHERE user_login='$newWpUser'); DELETE FROM ${prefix}users WHERE user_login='$newWpUser' LIMIT 1;";	
	#clean up the variable
	unset $newWpUser
}

########################################
######  CREATE MySQL FUNCTIONS  ########
########################################

function getURL(){
	printf "\n\n";
	mysql -u $dbUser -h $siteID --password=$dbPass $dbName -e "SELECT option_name, option_value FROM ${prefix}options where option_name='siteurl' OR option_name='home';"
} 

function setURL(){
	mysql -u $dbUser -h $siteID --password=$dbPass $dbName -e "UPDATE ${prefix}options SET option_value='$1' WHERE option_name='siteurlm'; UPDATE ${prefix}options SET option_value='$2' WHERE option_name='home'; "
}

function checkDBSize(){
    mysql -u $dbUser -h $siteID --password=$dbPass $dbName -e "SELECT table_name 'Table', table_rows 'Rows', data_length 'Data Length', index_length 'Index Length', round(((data_length + index_length) / 1024 / 1024),2) 'Size in MB' FROM information_schema.TABLES WHERE table_schema = '$dbName';";
	mysql -u $dbUser -h $siteID --password=$dbPass $dbName -e "SELECT table_schema 'Database', sum( data_length + index_length) / 1024 / 1024 'Size in MB' FROM information_schema.TABLES WHERE table_schema = '$dbName';"
}

function disablePlugin(){
	mysql -u $dbUser -h $siteID --password=$dbPass $dbName -e "UPDATE ${prefix}options SET option_value = 'a:0:{}' WHERE option_name = 'active_plugins';";
	printf "\nYour plug-ins have been disabled.\n";
}

function dbBackup(){
	date=$(date +%Y-%m-%d);
	sqlName=$(echo $dbName | awk -F"_" '{print $2}');
	mysqldump --add-drop-table -u $dbUser -h $siteID --password=$dbPass $dbName > ${sqlName}${date}.sql ;
	printf "\n\nYour database has been exported to ${sqlName}${date}.sql\n";
}

function repairDB(){
	mysqlcheck -ca --auto-repair -o -u $dbUser -h $siteID --password=$dbPass $dbName;
}

function interactiveShell(){
    mysql -h $siteID -u $dbUser --password=$dbPass $dbName;
}

##################################################
### This create sets a default .htaccess file  ###
##################################################

function htaccessDefault(){

########################################################################################
### This will create the new .htaccess file and set the rewrite rules for permalinks ###
########################################################################################
function permalink(){
        echo "# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress" > .htaccess;
}

########################################################
#######     rename the existing .htaccess file   #######
########################################################


#lets search for a .htaccess file.
        if [ "$(ls -a .htaccess 2> /dev/null)" == ".htaccess" ]; then
                printf "\n.htaccess file found. Would you like to back it up and set a default .htaccess with permalink rules?: ";
                echo "y\n?";
                        himus=true;
                        while [ "$himus" == true ]
                        do
                        read setHtaccess;
                                if [ "$setHtaccess" == "y" ];then
                                        himus=false
                                        mv .htaccess .htaccess.mtbak;
                                        permalink;
                                elif [ "$setHtaccess" == "n" ]; then
                                        himus=false
                                        read -t 2 -p "See you later dude.";
                                        break;
                                else
                                        echo "You need to enter in valid choice: y\n?";
                                fi
                        done
        else
		printf "\nNo .htaccess file found. Did you want to create a default .htaccess file with permilink rules: ";
                echo "y\n?";
                        himus=true;
                        while [ "$himus" == true ]
                        do
                        read newHtaccess;
                                if [ "$newHtaccess" == "y" ];then
                                        himus=false
                                        permalink;
                                elif [ "$newHtaccess" == "n" ]; then
                                        himus=false
                                        read -t 1 -p "Ok, whatever you want.";
                                        break;
                                else
                                        echo "You need to enter in valid choice: y\n?";
                                fi
                        done
        fi
}

##############################################
### Get the users input for secondary menu ###
##############################################

function dbConnect(){
	keepRun=true;
	while [ $keepRun ]
	do
		printf "\nWhat would you like to do?\n";
		cat <<- _EOF_
		(a) Check siteurl and home:
		(b) Update siteurl and home:
		(c) Reset admin password:
		(d) Create a temp WordPress user:
		(e) Check database size:
		(f) Create database backup:
		(g) Repair/Optimize database:
		(h) Disable all plugins:
		(i) Connect to MySQL:
		(j) Default .htaccess file with permalinks:
		(k) Create phpinfo page:
		(q) Exit:
		    
		Please enter your selection:
		_EOF_
			read choice;
		case $choice in
		    "a"|"A") getURL;;
		    "b"|"B") getLocation;;
                    "c"|"C") setpass;;
			"d"|"D") newUser;;
		    "e"|"E") checkDBSize;;
		    "f"|"F") dbBackup;;
		    "g"|"G") repairDB;;
		    "h"|"H") disablePlugin;;
		    "i"|"I") interactiveShell;;
		    "j"|"J") htaccessDefault;;
			"k"|"K") phpInfo;;
			#"l"|"L") siteClone;;
                    "q"|"Q") echo "You are about to exit dude...";
			read -t 1 nothing;
			rmScript;
			exit;;
		    *) echo "WHAT!?!?! I don't see an option for that. Try again please.";;
		esac
	done	
}


#################################
#######  INITIAL MENU  ##########
#################################

valid=false;
while [ $valid != true ]
do
###  Do you want to connect to the database
read -p "Do you want to make some edits to this site's configuration?y\n: " response;

if [ "$response" == "y" ]; then
 	dbConnect; 
elif [ "$response" == "n" ]; then
	valid=true;
	printf "\nOk, see you later.\n";
	read -t 1 p
	rmScript;
else
	valid=false;
	printf "\nPlease enter in a valid response.\n";
fi
done
}

#!/bin/bash

function listDomains(){
     find ~/domains/ -maxdepth 1 -type d | awk -F'/' '{print $7}' | sort -n;  
}

function cmsType(){
    cmsFile=$(find ./ -maxdepth 2 -type f -name wp-config.php 2> /dev/null);
    if [ "$cmsFile" == "" ];then
        echo "no wp-config.php found. Search for different CMS";
	elif [ "$cmsFile" == "./wp-config.php" ];then
	#	touch testFile;
		wpScript;
    elif [ "$cmsFile" == "./html/wp-config.php" ];then
		cd html;
	#	touch testFile;
		wpScript;
	else
    	echo "Nothing was located. Oops.";    
    fi
}    

function listDomains(){
	#get array listing
	domList=$(find ~/domains/ -maxdepth 1 -type d | awk -F'/' '{print $7}' | sort -h);
	#fill in array
	domArray=($(for i in $domList; do echo $i; done ));
	#output the array contents for the user to select from
	for (( i=0; i<"${#domArray[@]}"; i++ ));
	do
		echo "$((${i}+1)): ${domArray[$i]}";
	done
	read -p "Please enter your choice: " domChoice;
	cd ${HOME}/domains/${domArray[$((${domChoice}-1))]};
	cmsType;
}

    #set -x
    #run a while loop for the inital menu asking for the domain. 
    setD;
    runagain=true;
    while [ "$runagain" == true ]
    do
        echo "Enter in the domain name you want to alter:";
        echo "Enter L to view listed domains:";
        echo "Enter Q to quit:";
        read domain;
      	 
		#run through cases
		case $domain in
			"") printf "You need to actually enter something in. Try again\n\n";;
			"l"|"L") listDomains;;
			"q"|"Q") printf "\nSee you later Bro Montana!\n";
					 runagain=false;
					 rmScript;;
			*) if [ -d "${HOME}/domains/${domain}" ];
			   then
			   		printf "\nDirectory located\n\n";
					cd ${HOME}/domains/${domain};
					cmsType;
			   else
			   		printf "\nThe Directory does not seem to exist. Try again.\n\n";
			   fi;;
		esac

	done

