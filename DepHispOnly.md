# HISP Only Deployment (no source)

This section outlines step by step instructions on installing and deploying a Bare Metal instance of the Java reference implementation. The instructions contains steps for a select list of software platforms such as Windows, FreeBSD, Ubuntu, CentOS, and RedHat Enterprise linux.

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

Download and install 8 JRE from Oracle's download web [site](https://www.oracle.com/technetwork/java/javase/downloads/jre8-downloads-2133155.html).  After installing the JRE, set the JAVAHOME environment variable by following the instructions below:

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

##  Obtain Reference Implementation Stock Assembly

The stock assembly contains all of the pre-assembled and configured components of the Bare Metal deployment. Download the latest version of the stock assembly from the maven central repository [repository](http://repo.maven.apache.org/maven2/org/nhind/direct-project-stock/6.0/direct-project-stock-6.0.tar.gz).

**Note:** The maven central repository may black list some IP ranges such as virutal machines running in the Amazon EC2 cloud. Use the Sonatype repository if you are blocked from the maven central repository.

The assembly contains a root directly named direct and has the following folders under the root.

* apache-tomcat-9.0.16
* ConfigMgmtConsole
* DirectDNSServices
* james-jpa-guice-3.2.0
* tools

*Windows*

From a browser, download the desired version of the assembly from one the repositories above.

Example: Download version 6.0 - [direct-project-stock-6.0.tar.gz](http://repo.maven.apache.org/maven2/org/nhind/direct-project-stock/6.0/direct-project-stock-6.0.tar.gz). After downloading, unzip the contents to appropriate installation location.

*All Linux/Unix*

Obtain the URL for appropriate version of the assembly and download it the /opt directory by running wget command from the /opt directory. For example, to download version direct-project-stock-6.0.tar.gz from maven central, use the following commands:

```
 cd /opt
 sudo wget http://repo.maven.apache.org/maven2/org/nhind/direct-project-stock/6.0/direct-project-stock-6.0.tar.gz
```

Extract the contents of the assembly and set the DIRECT HOME logical using the following command. Note the name of the tar.gz file if you downloaded a different version:

```
 sudo tar xvfz direct-project-stock-6.0.tar.gz
 export DIRECT_HOME=`pwd`/direct
 echo "export DIRECT_HOME=$DIRECT_HOME" | sudo tee -a /etc/environment
```

## Launch Tomcat

Before running the James mail servier, the configuration and message monitiroing services must be running and some minimum configuration completed. All of these services run inside the Tomcat web server.

To start the tomcat server, run the following command from the DIRECT HOME/apache-tomcat-9.0.16/bin directory.

*Windows*

```
startup
```

*All Unix/Linux/FreeBSD*

```
sudo ./startup.sh
```

*Note:* It may take a few minutes for the web server to finish loading as it must initially deploy all of the services when run for the first time.

To validate that Tomcat and the configuration services loaded successfully, launch a browser window against the server node with the following URL:

```
http://<server>:8080/config-ui
```

You should be presented with the configuration ui login screen,

## Domain Name and Certificate Generation

The first step in running your mail server is configuring the domain and a loading a trust anchor and certificate(s) into the configuration ui.

First determine your HISPs domain name. Depending on the type of certificate resolution services you wish to host, your domain naming convention may slightly differ. Regardless of the certificate hosting model, you will need to have to have registered domain. For this document, we will assume you have a domain registered called example.com.

**Note:** Refer to the Direct Project [DNS Configuration Guide](http://wiki.directproject.org/DNS_Configuration_Guide) as a starting point for determining your DNS naming convention.

Now that we have our registered domain, we will host our HISP Direct messaging under the domain direct.example.com.

The next step is create a root certificate (anchor) for our domain and an X.509 certificate or pair of X.509 certificates for encrypting/decrypting and signing message. There are many different options for getting these certificates such as using openssl or obtaining a certificate from a commercial third party such as DigiCert. However the Direct Project reference implementation assembly ships with a tool called certGen for generating root CAs and certificates for the purpose of pilots and interop testing.

**NOTE:** The certificates generated by the certGen tool implement certificates that represent trust anchors and end entity certificates for domains and individual Direct addresses. However, these certificates do not implement a fully functional PKI (public key infrastructure) which would include multitude of additional operational aspects. PKIs are generally implemented by third party CAs such as DigiCert or VeriSign, but can by implemented by individual institutions if they resources to do so. PKI implementation is outside the scope of this document.

Full documentation for the certGen tool can be found [here](https://directprojectjavari.github.io/agent/CertGen). The documentation in the certGen link runs the certGen tool from the reference implementation source tree. In the Bare Metal assembly, the certGen tool is found under the /direct/tools directory that was extracted from the tar.gz file.

Run the certGen tool from tools directory using the following command:

*Windows*

```
certGen
```

*All Unix/Linux*

```
./certGen.sh
```

#### Certificate Generation

Now create a CA for your domain. In the certGen tool, enter a common name (CN:) for your new CA. For our domain direct.example.com, we might use something like Direct.Example.Com Root CA. Fill the other fields as needed. It is recommended you set the expiration to 1 year, the key strenth to at least 2048 bytes, and provide a password for your CA's private key.

After creating the CA, create a leaf cert and using your domain name as the CN: field and fill in all other fields as needed. It is recommended you set the expiration to at least 1 year, the key strength to at least 2044 bytes, and provide a password for your private key. After creating your CA and certificate, you should have the following similarly named files in your /tools directory (assuming the direct.example.com domain and no email address entered in the CA dialog. If an email address is entered, then the CA files will have the eamil address in the file name instead of the CN field).

* Direct.Example.com Root CA.der = Root CA file (trust anchor for you HISP)
* Direct.Example.com Root CAKey.der - Root CA private key file
* direct.example.com.der - Org certificate file
* direct.example.comKey.der - Org certificate private key file
* direct.example.com.p12 - Org certificate PKCS12 file

##### Single Use Certificates

The certGen tool does support generating single use certificates. If you wish to implement single use certificates, refer to this specific [section](SingleUseCerts).

## Import Anchors and Certificates

Before the security and trust agent can be run, you must create you domain in the configuration ui tool and import anchors and certificates. Follow the steps below to create your domain and import your trust anchor and certificate(s). A full description of the config ui and operations can be found [here](https://directprojectjavari.github.io/gateway/SMTPWebConfiguration).

1. Log into http://<server>:8080/config-ui with username: admin and password: direct
  * Click **Create New Domain**.
  * Enter the Domain Name and Postmaster E-Mail Address for the domain this HISP will be handling. Typical postmaster address is postmaster@<domain name>.
  * Choose ENABLED as the status.
  * Click **Add**
  
2. Click the Anchors tab.
  * Click **Choose File**... and browse to the location of your trust anchor, and select it.
  * Check Incoming and Outgoing
  * Choose ENABLED as the status.
  * Click **Add anchor**

3. Click *Certificates* at the top of the screen
  * Click **Choose File** and browse to the location of you org certificate PKCS12 file, and select it
  * Choose Unprotected PKCS12 as the private key type
  * Choose ENABLED as the status.
  * Click **Add Crtificate**
  
If you have multiple certificate files for scenarios such as single use certificates, repeat the previous 3 steps for each certificate file.

Before your HISP can communicate with other HISP, you must import anchors from other HISPs to establish trusted communication. You must also provide your trust anchor to the HISP(s) you are communicating with. There are a few options of HISPs that exist for interop testing that can be easily accessed.  An easier way is to import trust bundles and add that trust bundle to you domain.  A common test bundle is the DirectTrust Interop Test bundle found [here](https://bundles.directtrust.org/bundles/interopTestCommunity.p7b).  This includes an anchor for the following test domain:

* direct.securehealthemail.com
  * Testing HISP running the latest version of the Java Bare Metal assembly. Contact gm2552@cerner.com to establish a trust relationship.

## Configure and Run James Mail Server

First, configure james with your domain name. 

*Windows*

**NOTE:** You will need ant installed to use the batch file method.

To set the domain via the batch file, open a command prompt, CD to the %DIRECTHOME%/james-jpa-guice-3.2.0 directory and run the following command:

```
setdomain <your domain name>
```

*All Unix/Linux/*

Run the following commands:

```
 cd $DIRECT_HOME/james-jpa-guice-3.2.0
 sh ./setdomain.sh <your domain name>
```

Now start the Apache James mail server with security and trust agent with the following commands:

*Windows*

**NOTE:** The Windows version does not current support running as a background service.

```
james
```

*All Unix/Linux/FreeBSD*

```
james start
```

Now add your first user.

*Windows*

```
cd %DIRECTHOME%/james-jpa-guice-3.2.0
james-cli -h localhost adduser username password
```

*All Unix/Linux/FreeBSD*

```
cd $DIRECT_HOME/apache-james-3.0-beta4/bin
./james-cli.sh -h localhost adduser username password
```

**NOTE:**  The username should contain @domainname.

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

#### Secure Configuration Service Port (8080)

To secure the configuration service, it is recommended to limit access to port 8080 to localhost and/or a local subnet.

#### Secure Configuration Service Password

To further protect the configuration service, or if port 8080 must remain public, it is recommended to change the default password.  The default password is *direct* which is encrypted in the *<tomcat home>/webapps/config-ui/WEB-INF/classes/bootstrap.properties* file under the property *direct.configui.security.user.password*.  You can either change the password by putting the new password in plain text (remove the {bcrypt} before the password) or you can create an encrypted representation using an online bcrypt web [site](https://www.browserling.com/tools/bcrypt).  **NOTE:** If you are using an encrypted password in the properties file, be sure to leave the *{bcrypt}* text before the encrypted text.

Restart the tomcat server for the changes to take affect.

#### Add Own Server Certificate to James

If you are using James 3, the default configuration enables last mile encryption (SSL and TLS) on the edge POP3, SMTP, and IMAP protocols. This is enabled via configuration in the imapserver.conf, pop3server.conf, and smtpserver.conf files. For POP3 and IMAP4, all connections use the STARTTLS command. For the SMTP protocol, the configuration enables STARTTLS for local outgoing connections that must be authenticated, but all incoming SMTP exchanges from external systems will continue to use non SSL/TLS connections.

To enable encryption, a server certificate must be installed along with its private key. The James 3 configuration comes pre-packaged with a self signed certificate. Most email and edge clients will display a warning to the user noting that the certificate should probably not be trusted. At this point, it is recommneded that you either install your own certificate or install a certificate from a PKI third party. In either case, you will need to create your own keystore file with your own certificate and deploy it in the James conf directory. This should be the same place where the default cakeystore.jks is located. After deploying your own keystore, you will need to update the SSL connection section of the imapserver.xml, pop3server.xml, and smtpserver.xml files with the location of your own keystore file and passphrase for the keystore file.

#### Tweak Message Monitoring Service Settings

The message monitoring service is preconfigured with common settings, but can be tweaked to your specific requirements. See the monitoring deployment [guide](https://directprojectjavari.github.io/direct-msg-monitor/DepAndConfig) for more details.

#### Define Policy Definitions

Starting with version 3.0, an optional module is available for defining X509 certificate policies. See the policy enablement module (direct-policy) users [guide](https://directprojectjavari.github.io/direct-policy/) for full details.

