# HISP Only Deployment (no source)

This section outlines step by step instructions on installing and deploying a Bare Metal instance of the Java reference implementation. The instructions contains steps for a select list of software platforms such as Windows, FreeBSD, Ubuntu, CentOS, and RedHat Enterprise linux.

## Major Updates in Version 8.1+

Version 8.1 is a smaller technology update with minor updates and feature enhancements: Main features include:

* Update to SpringBoot 2.5.x
* Updating to BouncyCastle jdk18on
* Defaults to OAEP Key Encryption with SHA1 Digests for message generation
* Supports ability to decrypt messages using OAEP Key Encryption with SHA256 Digests
* New options to set the key encryption and key digest algorithms
* Documentation to support CloudNative deployment model

## Major Updates in Version 6.0+

This document covers only versions 6.0 and later.  For documentation of earlier versions, please see docs [here](http://api.directproject.info/assembly/stock/5.1/users-guide/depl-hisp-only.html).

Version 6.0 is a major technology update replacing many implementation and breaking internal interfaces in same areas: Features include:

* Java 8+ required
* Removal of support of James 2 and James 3 beta.  James 3.2.0 is now the base version.
* Replacement of JPA DAO classes with Spring Data repository interfaces.
* Update to Spring 5.1.x, introduction of SpringBoot 2.1.x SpringCloud Greenwich
* Replacement of Jersey with Spring MVC
  * Many service are implemented as reactive web services
* Removal of Guice and replace with Spring configuration
  * Simplified configuration in property files
  * Ability to centralize configuration in SpringCloud configuratin server
* Update to Tomcat 9.x
* Ability to run services as SpringBoot stand-alone applications vs Tomcat servlet containers
  * Also supports running in CloudFoundry with sample manifest files.
  * Service discovery via Eureka
  
## Assumptions
	
* User is running one of the following software platforms. Other platforms are supported and may only required slight variations of the instructions listed this section, but the Bare Metal install has only been validated on the following platforms: 

  * Windows
    * Server 2016 or later
    * Windows 7 of later
  * Ubuntu Linux
    * 18.04 (Bionic Beaver)
    * 18.10 (Cosmic Cuttlefish)
  * CentOS 7.x
  
  
* Assumed that the install has administrative privileges on the install box.
  * Root or sudo access for linux/unix based platforms
  * Administrator privileges for Windows based platforms
  
* Assumed user has registered a domain with an accredited domain registrar such as [GoDaddy](http://www.godaddy.com/)

## General Tools and Runtimes

The reference implementation requires some tools to be available on the platform to install and run the Bare Metal components.

* Unzip
* Ant
* Java 8

##### Unzip

An unzip tool is required to unpack the stock assembly. Recommended tools and installation locations are listed below:

*Windows*

Any one of the following will work for Windows (these are preferred over the build in Window zip utility):

* [Winzip](https://www.winzip.com)
* [WinRar](https://www.rarlab.com)

*Ubuntu*

Install unzip using the following command:

```
sudo apt-get install unzip
```

*CentOS*

Unzip tools should already be installed, but if not execute the following commands with root or sudo privileges:

```
 yum install unzip
 yum install gzip
 yum install tar
```

##### Ant

The Ant tool is used for setting the domain name in the Apache James server.

*Windows*

Download Apache Ant from the following location and follow in the install instructions under Documentation/Manual located on the upper left side of the site below

* [Apache Ant](http://ant.apache.org/bindownload.cgi)

*Ubuntu*

Install ant using the following command:

```
sudo apt-get install ant
```

Install ant using the following command with root or sudo privileges:

```
yum install ant
```

##### Java 8 SE

The Java 8 SE platform provides the runtime environment that all of the Bare Metal components will run in.

*Windows*

Download and install 8 JRE from Oracle's download web [site](https://www.oracle.com/technetwork/java/javase/downloads/jre8-downloads-2133155.html) 
(you may be required to sign up for an account).
After installing the JRE, set the JAVAHOME environment variable by following the instructions below:

* Right click on "My Computer" (may be in different locations depending on the Windows version) and select Properties
* If running later versions of Windows, you may be presented "ControlSystem" panel. If so, click Advanced system settings on the left side of the window.
* In the System Properties Dialog, click the Advanced tab and then click Environment Variables.
* Under System Variables click New.
* Use the following settings example substituting with the appropriate folder:

```
 Variable Name: JAVA_HOME
 Variable Value: C:\Program Files\java\jre1.8.0_xxx
```

Click OK on all screens.


*Ubuntu*

The Oracle JREs are supported in the WebUpdt8 Personal Package Archive (PPA) which automatically downloads and installs the JRE.

To install PPA, follow the commands below:

```
sudo add-apt-repository ppa:webupd8team/java
sudo apt-get update
```

To install Oracle Java 8, run the following command and accept the licenses.

```
sudo apt-get install oracle-java8-installer
sudo apt-get install oracle-java8-set-default
export JAVA_HOME=/usr/lib/jvm/java-8-oracle
echo "export JAVA_HOME=$JAVA_HOME" | sudo tee -a /etc/environment
```

*CentOS*

Obtain/downlaod the JRE 8 Update 202 package using the following command:

```
wget --no-cookies --no-check-certificate --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" https://download.oracle.com/otn-pub/java/jdk/8u202-b08/1961070e4c9b4e26a04e7f5a083f551e/jre-8u202-linux-x64.rpm
```
After downloading, execute the following commands to install the JRE

```
sudo yum localinstall jre-8u202-linux-x64.rpm 
```

Finally set the JAVAHOME environment variable for the new JDK using the following commands:

```
export JAVA_HOME=/usr/java/jre1.8.0_202-amd64
echo "export JAVA_HOME=$JAVA_HOME" | sudo tee -a /etc/environment
```

##### Java Cryptographic Extensions

The Sun JRE/JDK requires the JCE policy jars to be updated to allow for unlimited strength encryption. The policy files must be downloaded separately and copied in the JRE library.

For all platforms, download the jce policy file using a web browser. For Unix/Linux systems, it may be necessary to manually copy or FTP the file from a system with a UI to the Unix/Linux node.


* [Java 8](http://www.oracle.com/technetwork/java/javase/downloads/jce8-download-2133166.html)


*Windows*

Unzip the downloaded file and copy the jar files from the jce directory to the JAVAHOME/jre/lib/security folder (Example: C:Program Filesjavajre6libsecurity). Overwrite the existing files.

*All Linux/Unix*

From the directory where you downloaded and placed the jce zip file, run the following commands:

```
 unzip <jce zip file name>
 cd <Unzipped Directory Name>
 sudo cp local_policy.jar $JAVA_HOME/jre/lib/security
 sudo cp US_export_policy.jar $JAVA_HOME/jre/lib/security
```

## Deploy Reference Implementation Core Components

There are two deployment configurations for the Java Reference Implementation.  The links below give detailed instructions for each option:

* [Legacy Deployment](LegacyDeployment.md): This consists of the legacy Apache Tomcat along with Apache James Deployment
* [Cloud Native Deployment](CloudNativeDeployment.md): This consists of a contemporary Cloud Native deployment model with multiple


## DNS Records

Now that your HISP is running, you need to make it available to the public internet. If you intend to make your HISP's certificate available via DNS CERT records, you will need to install and configure the Direct DNS Server. Instructions can be found in the DNS Servers users/deployment [guide](https://directprojectjavari.github.io/dns/). This guide includes directions on integrating with GoDaddy.

If you are not using DNS to distribute your certificates (i.e. if you are going to use LDAP), you may use your registrar's DNS configuration tooling to setup MX records for you HISP.

## Distributing Certificates

The preferred distribution mechanism for distributing your HISP's org certificate is DNS CERT records. Instructions for setting up the Direct DNS server are found in the DNS server deployment [guide](https://directprojectjavari.github.io/dns/).

**NOTE:** Some OS distributions such as Ubuntu may already be running their own DNS server process. If the OS is already running a DNS server bound to the DNS ports (TCP and UDP ports 53), then you will need to stop these services before running the Direct DNS server. For example, to determine if Ubuntu already has a DNS running, run the following command and check for a process listening on port.

```
netstat -anp | grep 53
```

Another alternative is LDAP. The default settings in the security and trust agent will attempt to use the Direct LDAP specication if SRV records can be found. The LDAP standards can be found on the S&I framework's Certificate Discovery for Direct Project workgroup [page](https://docs.google.com/document/d/1igDpIizm7CTfV-fUw_1EnrCUGIljFEgLPRHpgK5iaec/edit).

A fall back alternative is manually distributing your org certificate to the HISPs that you will communicate. This is an out of band process that will require you to determine how to get your certificate to the HISP. Likewise another HISP may need to manually give you their certificate(s) if they do not support DNS or LDAP discovery. To add another HISPs certificate (not anchor) to you HISP, import the certificate file into the Certificates section of the configuration ui tool.

## Recommended Next Steps

The following are optional, but recommended, next steps to secure your environment. These are only small configuration tweaks; other configuration options that cover specific areas are covered in the deployment options [section](ImpOptions).

#### Secure Internal Service Ports

To secure internal services, it is recommended to limit access the service ports to localhost and/or a local subnet.

#### Secure Configuration Service Password

To further protect internal configuration service, or if ports must remain public, it is recommended to change the default password for the configuration service.  The default password is *direct* which located in the following locations depending on your deployment model:

- Legacy Deployment

The default password is encrypted in the *<tomcat home>/webapps/config-ui/WEB-INF/classes/bootstrap.properties* file under the property *direct.configui.security.user.password*.  You can either change the password by putting the new password in plain text (remove the {bcrypt} before the password) or you can create an encrypted representation using an online bcrypt web [site](https://www.browserling.com/tools/bcrypt).  **NOTE:** If you are using an encrypted password in the properties file, be sure to leave the *{bcrypt}* text before the encrypted text.

Restart the tomcat server for the changes to take affect.

- Cloud Native Deployment

The default password is contained withing the code itself, but can be overridden by creating an `application.properties` or `application.yaml` file in the same
directory as the config-service.jar file and setting the password under the property *direct.configui.security.user.password*.  You can either change the password by putting 
the new password in plain text (remove the {bcrypt} before the password) or you can create an encrypted representation using an online bcrypt web [site](https://www.browserling.com/tools/bcrypt).  **NOTE:** If you are using an encrypted password in the properties file, be sure to leave the *{bcrypt}* text before the encrypted text 

You can use any other Spring configuration method to set the password property (you don't have to use an application.properties or application.yaml file) such as
JVM parameters or even an external source like Spring Cloud Config.

Restart the configuration service process for the changes to take effect.


#### Add Own Server Certificate to James

If you are using James 3, the default configuration enables last mile encryption (SSL and TLS) on the edge POP3, SMTP, and IMAP protocols. This is enabled via configuration in the imapserver.conf, pop3server.conf, and smtpserver.conf files. For POP3 and IMAP4, all connections use the STARTTLS command. For the SMTP protocol, the configuration enables STARTTLS for local outgoing connections that must be authenticated, but all incoming SMTP exchanges from external systems will continue to use non SSL/TLS connections.

To enable encryption, a server certificate must be installed along with its private key. The James 3 configuration comes pre-packaged with a self signed certificate. Most email and edge clients will display a warning to the user noting that the certificate should probably not be trusted. At this point, it is recommneded that you either install your own certificate or install a certificate from a PKI third party. In either case, you will need to create your own keystore file with your own certificate and deploy it in the James conf directory. This should be the same place where the default cakeystore.jks is located. After deploying your own keystore, you will need to update the SSL connection section of the imapserver.xml, pop3server.xml, and smtpserver.xml files with the location of your own keystore file and passphrase for the keystore file.

#### Tweak Message Monitoring Service Settings

The message monitoring service is preconfigured with common settings, but can be tweaked to your specific requirements. See the monitoring deployment [guide](https://directprojectjavari.github.io/direct-msg-monitor/DepAndConfig) for more details.

#### Define Policy Definitions

Starting with version 3.0, an optional module is available for defining X509 certificate policies. See the policy enablement module (direct-policy) users [guide](https://directprojectjavari.github.io/direct-policy/) for full details.


