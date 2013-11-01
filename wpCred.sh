#!/bin/bash

echo
echo       :::::::::::::::::::::::::::::::::::::
echo       :::::: WordPress Configuration ::::::
echo       :::::::::::::::::::::::::::::::::::::
echo

dbName=$(cat wp-config.php | grep "define('DB_NAME" | awk -F"'" '{print $4}')
dbUser=$(cat wp-config.php | grep "define('DB_USER" | awk -F"'" '{print $4}')
dbPass=$(cat wp-config.php | grep "define('DB_PASSWORD" | awk -F"'" '{print $4}')
dbHost=$(cat wp-config.php | grep "define('DB_HOST" | awk -F"'" '{print $4}')

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
echo Current DB host: $dbHost
echo ---------------------------------------------------------
echo Current DB prefix: $prefix
echo ---------------------------------------------------------


#get true internal-db host name
#this will get the site ID as just a numeral
tempSiteID=$(echo $HOME | awk -F'/' '{print $3}')

#make is internal-db.s######.gridserver.com
siteID=internal-db.s${tempSiteID}.gridserver.com


###  Checking to see how the database host is set up ###
if [ "$dbHost" == "$siteID" ]; then
	printf "\nDB host looks right. Either way, we are using $siteID\n";
elif [ "$dbHost" == "external-db.s${tempSiteID}.gridserver.com" ]; then
	printf "\nYou may want to use internal-db.s${tempSiteID}.griderver.com";
elif [ "$dbHost" == '$_ENV['DATABASE_SERVER']' ]; then
	printf "\nDatabase host set with PHP enviroment variable.";
else
	echo "You may need to edit your database hostname!!!";
	echo "Either way, we are using $siteID";
fi

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
            	printf "You need to start with http:// or https://\n";
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
#set -x
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


##############################################
### create new function for mysql changes ####
##############################################

function dbConnect(){
	keepRun=true;
		while [ $keepRun ]
		do
			printf "\nWhat would you like to do?\n";
			printf "(a) Check siteurl and home:\n(b) Update siteurl and home:\n(c) Reset admin password:\n(q) Exit:\n";
			printf "Please enter your selection:"
				read choice;
			if [ "$choice" == "a" ]; then
				getURL;
			elif [ "$choice" == "b" ]; then 
				getLocation;
			elif [ "$choice" == "c" ]; then
				echo "This function is still in dev mode. It should work though.";
				setpass;
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
printf "\n\nDo you want to connect to the database?\n";
echo "y\n?"
read response;

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

