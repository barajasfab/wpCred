red='\e[0;31m'; NC='\e[0m';
printf "\n${red}Domains with perms set to unreadable:${NC}\n";
find ~/domains/ -maxdepth 2 -type d ! -perm -0750 | cut -d / -f 7 | sort -n;
blue='\e[1;34m';
printf "\n${blue}Domains with readable permissions:${NC}\n";
find ~/domains/ -maxdepth 2 -type d -name html -perm -750 | cut -d / -f 7 | sort -n;