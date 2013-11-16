#!/bin/bash

#set -x

dbName=$(cat wp-config.php | grep "DB_NAME" | awk -F"'" '{print $4}')
dbUser=$(cat wp-config.php | grep "DB_USER" | awk -F"'" '{print $4}')
dbPass=$(cat wp-config.php | grep "DB_PASSWORD" | awk -F"'" '{print $4}')

## get tempSiteID
tempSiteID=$(echo $HOME | awk -F"/" '{print $3}');

## set the dbHost back to internal-db.sxxxxxx.gridserver.com
siteID="internal-db.s${tempSiteID}.gridserver.com";

#####################################
## setting new functions for grep ###
#####################################
function grepLocal(){
  dbHost=$( grep -i -o localhost wp-config.php);
}
## grepping for php enviro database server
function grepEnviro(){
  dbHost=$(grep -E -i -o ENV{\'DATABASE_SERVER\'} wp-config.php);
}
## grep to see if it's external ##
function grepDB(){
  dbHost=$(grep "DB_HOST" wp-config.php | awk -F"'" '{print $4}' )
}

#####################################
###  Switch DB host in wp-config  ###
#####################################
function switchDB(){
	sed -i "/.*DB_HOST.*/c\define('DB_HOST','${siteID}');" ./wp-config.php;
}

################################
## database selection output  ##
################################
grepLocal;

######################################
### used to output current DB host ###
######################################
function prelimHostCheck(){
if [ "$dbHost" != "localhost" ];then
    grepEnviro;
        if [ "$dbHost" != "ENV{'DATABASE_SERVER'}" ];then
           grepDB;
              if [ "$dbHost" != "external-db.s${tempSiteID}.gridserver.com" ]; then
					if [ "$dbHost" != "${siteID}" ]; then
						printf "You may want to check your database host";
					else
						break;
					fi
              else
                   break;
              fi  
        else
	       break;
        fi
else
    break;
fi
}

prelimHostCheck;

################################
#####   check db host   ########
################################
function checkHost(){
if [ "$dbHost" != "localhost" ];then
    grepEnviro;
       if [ "$dbHost" != "ENV{'DATABASE_SERVER'}" ];then
          grepDB;
              if [ "$dbHost" != "${siteID}"  ]; then
                   printf "\n\nYou may want to check your database host.\n";
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
		done
              else
                   printf "\n\nEverything looks good.\n\n";
              fi  
       else
	    printf "\n\nYou are currently using the PHP enviro variable for database server.\n\n";
      fi
else
    printf "\n\nYour database server is set as localhost.\n";
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
                done
fi
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
	if [ "$dbHost" == "ENV{'DATABASE_SERVER'}" ]; then
		echo Current DB host: \$${dbHost};
	else
		echo Current DB host: $dbHost;
	fi
echo ---------------------------------------------------------
echo Current DB prefix: $prefix
echo ---------------------------------------------------------

## check the db host
checkHost;

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
######  CREATE MySQL FUNCTIONS  ########
########################################

function getURL(){
	printf "\n\n";
	mysql -u $dbUser -h $siteID --password=$dbPass $dbName -e "SELECT option_name, option_value FROM ${prefix}options where option_name='siteurl' OR option_name='home';"
} 

function setURL(){
	mysql -u $dbUser -h $siteID --password=$dbPass $dbName -e "UPDATE ${prefix}options SET option_value='$1' WHERE option_name='siteurl'; UPDATE ${prefix}options SET option_value='$2' WHERE option_name='home'; "
}

function checkDBSize(){
        mysql -u $dbUser -h $siteID --password=$dbPass $dbName -e "SELECT table_name 'Table', table_rows 'Rows', data_length 'Data Length', index_length 'Index Length', round(((data_length + index_length) / 1024 / 1024),2) 'Size in MB' FROM information_schema.TABLES WHERE table_schema = '$dbName';";
	mysql -u $dbUser -h $siteID --password=$dbPass $dbName -e "SELECT table_schema 'Database', sum( data_length + index_length) / 1024 / 1024 'Size in MB' FROM information_schema.TABLES WHERE table_schema = '$dbName';"
}


##################################################
### This create sets a default htaccess file  ####
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
			printf "(a) Check siteurl and home:\n(b) Update siteurl and home:\n(c) Reset admin password:\n(d) Set default .htaccess file with permalinks:\n(f) Check database size:\n(q) Exit:\n"
			printf "Please enter your selection:"
				read choice;
			if [ "$choice" == "a" ]; then
				getURL;
			elif [ "$choice" == "b" ]; then 
				getLocation;
			elif [ "$choice" == "c" ]; then
				setpass;
			elif [ "$choice" == "d" ]; then
				htaccessDefault;
			elif [ "$choice" == "e" ]; then
				alterDBHost;
			elif [ "$choice" == "f" ]; then
				checkDBSize;
			elif [ "$choice" == "q" ]; then
				echo "You are about to exit dude...";
				read -t 1 nothing;
				exit;
			else
				printf "\nPlease enter in a valid choice:\n";
			fi
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
 	dbConnect 
	#valid=true;
	#mysql
	#mysql $dbName $dbUser $dbHost $dbPass
elif [ "$response" == "n" ]; then
	valid=true;
	printf "\nOk, see you later.\n";
	read -t 1 p
else
	valid=false;
	printf "\nPlease enter in a valid response.\n";
fi
done
