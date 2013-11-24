#!/bin/bash

#set -x
#run a while loop for the inital menu asking for the domain. 
runagain=true;
    while [ "$runagain" == true ]
    do

        echo "Enter in the domain name you want to alter:";
        echo "Enter 0 to quit:";
        read domain;
        
    if [ "$domain" == "0" ];then
        printf "\nSee you later Bro Montana!\n";
        runagain=false;
    else
        echo "you selected $domain"
        located=$(find ~/domains/ -maxdepth 2 -type d -name ${domain} 2> /dev/null;)

        if [ "$located" == "$HOME/domains/${domain}" ]; then
            # this will be used to 
            echo "Located the following path: ${located}";
            cd ${located};
            pwd;
            runagain=false;
        else
            echo "Dude, nothing was located for ${domain}";
            echo "Please try again";
            runagain=true;
        fi
    fi
    done
