# Configuration and Message Monitor Storage

By default, the configuration and message monitor services uses the embedded file based Derby database. Although this simplifies an out of the box solution deployment, it has several disadvantages:

* It only allows one process to access it at any one time limiting the ability to run multiple instances of the configuration service for high availability and load balancing.
* Unless mounted on a network share, it is only available on the local machine.
* It is not redundant and providers no fail over options.

These are only a small collection of issues and it becomes obvious that an enterprise/distributed database solution is needed for a robust production solution.

The configuration and message monitoring services database configuration is held in a file named *bootstrap.properties* under the <tomcat home>\webapps\<app name>\WEB-INF\classes directory.  They use the standard spring datasource properties.  To connect to different database source, simply update these properties with proper database settings:

* spring.datasource.url=
* spring.datasource.username=
* spring.datasource.password=

Additional settings can be found in Spring [appendix A](https://docs.spring.io/spring-boot/docs/current/reference/html/common-application-properties.html) under the DATASOURCE section.

Other database such as Oracle allow for finer grained tuning via properties; consult your database vendor for more information.

After you migrate the services to your new distributed data source, it is recommended that you consider deploying multiple instance of the tomcat server using a fault tolerant and load balance configuration (instructions are beyond the scope of this document).