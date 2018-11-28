#/bin/sh
case "$1" in
    start)
        echo Starting James
        nohup java -classpath "james-server-jpa-guice.jar:james-server-jpa-guice.lib/*:james-server-jpa-guice.lib" -javaagent:james-server-jpa-guice.lib/openjpa-3.0.0.jar -Dlogback.configurationFile=conf/logback.xml -Dworking.directory=. org.apache.james.JPAJamesServerMain > /dev/null 2>&1  &
        echo $! > ./pid
        echo "."
        ;;
    stop)
        echo Stopping James
        kill $(cat ./pid)
        rm ./pid
        echo "."
        ;;   
    restart)                
        echo Stopping James
        kill $(cat ./pid)
        rm ./pid
        echo "."  
        echo Starting James
        nohup java -classpath "james-server-jpa-guice.jar:james-server-jpa-guice.lib/*:james-server-jpa-guice.lib" -javaagent:james-server-jpa-guice.lib/openjpa-3.0.0.jar -Dlogback.configurationFile=conf/logback.xml -Dworking.directory=. org.apache.james.JPAJamesServerMain > /dev/null 2>&1  &
        echo $! > ./pid
        echo "."
        ;; 
    console)
        echo Starting James
        java -classpath "james-server-jpa-guice.jar:james-server-jpa-guice.lib/*:james-server-jpa-guice.lib" -javaagent:james-server-jpa-guice.lib/openjpa-3.0.0.jar -Dlogback.configurationFile=conf/logback.xml -Dworking.directory=. org.apache.james.JPAJamesServerMain
        ;;
      *)
        echo "Usage: james.sh start|stop|restart|console"
        exit 1
        ;;  
esac                       