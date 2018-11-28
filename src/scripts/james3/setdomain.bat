set DIRECT_DOMAIN=%1
ant -q -f ./set-domain.xml
echo "Domain set to %1"
echo "Postmaster set to postmaster@%1"
