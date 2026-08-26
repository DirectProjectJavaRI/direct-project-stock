---
title: HISP Only Deployment (no source)
---

# HISP Only Deployment (no source)

This section outlines step-by-step instructions for installing and deploying a Bare Metal instance of the Java Reference Implementation. The instructions cover a select list of software platforms, such as Windows and Ubuntu.

## Major Updates in Version 9.0.x

Version 9.0 is a major technology update, replacing many implementations and breaking internal interfaces in some areas. It also officially retires the legacy deployment model (Apache Tomcat and Apache James) and moves exclusively to the Cloud Native deployment model. Key features include:

* Removal of the legacy deployment model
* Updated to Spring Boot 4.1.0
* Requires Java 17 as the minimum version; Java 21 or higher is recommended
* New Spring-based configuration parameters
* Better XD support, including:
  * Per-address configuration for routing to XD endpoints (versus a single global setting for one and only one XD endpoint)
  * Updated step-up and step-down XDM and XDR conversion in line with ONC certification libraries
  * Support for notification messages in line with the latest Direct Project XD implementation guides

## Major Updates in Version 8.1+

Version 8.1 is a smaller technology update with minor updates and feature enhancements. Key features include:

* Update to Spring Boot 2.5.x
* Update to the BouncyCastle jdk18on library
* Defaults to OAEP key encryption with SHA-1 digests for message generation
* Supports decrypting messages using OAEP key encryption with SHA-256 digests
* New options to set the key encryption and key digest algorithms
* Documentation to support the Cloud Native deployment model

## Major Updates in Version 6.0+

This document covers only versions 6.0 and later. For documentation of earlier versions, please see the docs [here](http://api.directproject.info/assembly/stock/5.1/users-guide/depl-hisp-only.html).

Version 6.0 is a major technology update, replacing many implementations and breaking internal interfaces in some areas. Features include:

* Java 8+ required
* Removal of support for James 2 and James 3 beta. James 3.2.0 is now the base version.
* Replacement of JPA DAO classes with Spring Data repository interfaces.
* Update to Spring 5.1.x; introduction of Spring Boot 2.1.x and Spring Cloud Greenwich
* Replacement of Jersey with Spring MVC
  * Many services are implemented as reactive web services
* Removal of Guice, replaced with Spring configuration
  * Simplified configuration in property files
  * Ability to centralize configuration in a Spring Cloud configuration server
* Update to Tomcat 9.x
* Ability to run services as standalone Spring Boot applications instead of within Tomcat servlet containers
  * Also supports running in Cloud Foundry, with sample manifest files provided
  * Service discovery via Eureka

## Assumptions

* These instructions assume you are running one of the following software platforms. Other platforms may work with only slight variations to the steps in this section, but the Bare Metal install has only been validated on:

  * Windows
  * Ubuntu Linux

* The install requires administrative privileges on the target machine.
  * Root or sudo access for Linux platforms
  * Administrator privileges for Windows-based platforms

* The user has registered a domain with an accredited domain registrar such as [GoDaddy](http://www.godaddy.com/).

## General Tools and Runtimes

The reference implementation requires certain tools to be available on the platform to install and run the Bare Metal components.

* Java 17

For Legacy Deployments (RI 8.1 and previous versions only):

* Unzip
* Ant
* Java 8

##### Unzip (Legacy Only)

An unzip tool is required to unpack the stock assembly. Recommended tools and installation locations are listed below:

*Windows*

Any one of the following will work for Windows (these are preferred over the built-in Windows zip utility):

* [Winzip](https://www.winzip.com)
* [WinRar](https://www.rarlab.com)

*Ubuntu*

Install unzip using the following command:

```
sudo apt-get install unzip
```


##### Ant (Legacy only)

The Ant tool is used to set the domain name in the Apache James server.

*Windows*

Download Apache Ant from the following location and follow the installation instructions under Documentation/Manual, found on the left side of the site below:

* [Apache Ant](http://ant.apache.org/bindownload.cgi)

*Ubuntu*

Install Ant using the following command:

```
sudo apt-get install ant
```

##### Java 17

Starting with RI 9.0, Java 17 is required as the minimum version, with Java 21 or 24 recommended.

**Note:** OpenJDK is the recommended distribution — it is free to use in production without a commercial license (unlike Oracle JDK, which requires one for production use under Oracle's current licensing terms) and includes the full runtime, so it is suitable even if you only need to run (not build) the reference implementation. The steps below use [Eclipse Temurin](https://adoptium.net/), a widely used, actively maintained OpenJDK distribution, but any OpenJDK 17 build will work.

*Windows*

1. Download the Windows x64 Installer (`.msi`) for Java 17 from the Eclipse Temurin site (no account/login required):
   * [Eclipse Temurin 17 Downloads](https://adoptium.net/temurin/releases/?version=17)
2. Run the downloaded installer and follow the prompts. On the "Custom Setup" screen, ensure **Set JAVA_HOME variable** and **Add to PATH** are enabled (they are selected by default) so the installer configures the `JAVA_HOME` environment variable and `PATH` for you.
3. Open a new command prompt and verify the install:

```
java -version
```

You should see output similar to `openjdk version "17.x.x"`.

*Ubuntu*

The recommended method is to install OpenJDK 17 from the Eclipse Temurin APT repository, which keeps the package up to date via `apt`.

1. Add the Eclipse Temurin APT repository and its signing key:

```
sudo apt update
sudo apt install -y wget apt-transport-https gpg
wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/adoptium.gpg
echo "deb https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | sudo tee /etc/apt/sources.list.d/adoptium.list
sudo apt update
```

2. Install the JDK package:

```
sudo apt install temurin-17-jdk
```

3. Verify the installation:

```
java -version
update-alternatives --list java
```

4. Set `JAVA_HOME` to the installed JDK location and persist it for future sessions:

```
export JAVA_HOME=/usr/lib/jvm/temurin-17-jdk-amd64
echo "export JAVA_HOME=$JAVA_HOME" | sudo tee -a /etc/environment
```

**Alternative (manual tarball install):** If you prefer not to use `apt`, or are on a non-Debian-based distribution, download the `.tar.gz` archive instead from the [Eclipse Temurin Downloads page](https://adoptium.net/temurin/releases/?version=17), extract it under `/usr/lib/jvm/`, and set `JAVA_HOME`/`PATH` manually:

```
sudo mkdir -p /usr/lib/jvm
sudo tar -xzf OpenJDK17U-jdk_x64_linux_hotspot_17.0.x_y.tar.gz -C /usr/lib/jvm
export JAVA_HOME=/usr/lib/jvm/jdk-17.0.x+y
export PATH=$JAVA_HOME/bin:$PATH
echo "export JAVA_HOME=$JAVA_HOME" | sudo tee -a /etc/environment
```

##### Java 8 SE (Legacy Only)

The Java 8 SE platform provides the runtime environment that all Bare Metal components run in.

*Windows*

Download and install the Java 8 JRE from Oracle's download [site](https://www.oracle.com/technetwork/java/javase/downloads/jre8-downloads-2133155.html) (you may be required to create an account). After installing the JRE, set the `JAVA_HOME` environment variable by following the instructions below:

* Right-click on "My Computer" (may be in a different location depending on the Windows version) and select Properties.
* On later versions of Windows, you may be presented with the "System" settings panel. If so, click Advanced system settings on the left side of the window.
* In the System Properties dialog, click the Advanced tab, then click Environment Variables.
* Under System Variables, click New.
* Use the following settings as an example, substituting the appropriate folder:

```
 Variable Name: JAVA_HOME
 Variable Value: C:\Program Files\java\jre1.8.0_xxx
```

Click OK on all screens.

*Ubuntu*

The Oracle JREs are supported through the WebUpd8 Personal Package Archive (PPA), which automatically downloads and installs the JRE.

To add the PPA, run the following commands:

```
sudo add-apt-repository ppa:webupd8team/java
sudo apt-get update
```

To install Oracle Java 8, run the following commands and accept the license agreement.

```
sudo apt-get install oracle-java8-installer
sudo apt-get install oracle-java8-set-default
export JAVA_HOME=/usr/lib/jvm/java-8-oracle
echo "export JAVA_HOME=$JAVA_HOME" | sudo tee -a /etc/environment
```

##### Java Cryptographic Extensions (Legacy Only)

The Sun JRE/JDK for Java 8 requires the JCE (Java Cryptography Extension) policy JARs to be updated to allow for unlimited-strength encryption. The policy files must be downloaded separately and copied into the JRE library.

For all platforms, download the JCE policy file using a web browser. On Unix/Linux systems, it may be necessary to manually copy or FTP the file from a system with a graphical interface to the Unix/Linux node.

* [Java 8](http://www.oracle.com/technetwork/java/javase/downloads/jce8-download-2133166.html)

*Windows*

Unzip the downloaded file and copy the JAR files from the jce directory to the `JAVA_HOME/jre/lib/security` folder (example: `C:\Program Files\java\jre6\lib\security`). Overwrite the existing files.

*All Linux/Unix*

From the directory where you downloaded and placed the JCE zip file, run the following commands:

```
 unzip <jce zip file name>
 cd <Unzipped Directory Name>
 sudo cp local_policy.jar $JAVA_HOME/jre/lib/security
 sudo cp US_export_policy.jar $JAVA_HOME/jre/lib/security
```

## Deploy Reference Implementation Core Components

There are two deployment configurations for the Java Reference Implementation. The links below give detailed instructions for each option:

* [Cloud Native Deployment](cloud-native-deployment): A contemporary deployment model composed of multiple discrete microservices. Required starting with RI 9.0.
* [Legacy Deployment (RI 8.1 and Previous)](legacy-deployment): The legacy deployment model based on Apache Tomcat and Apache James.

## DNS Records

Now that your HISP is running, you need to make it available to the public internet. If you intend to make your HISP's certificate available via DNS CERT records, you will need to install and configure the Direct DNS Server. Instructions can be found in the DNS Server's user and deployment [guide](https://directprojectjavari.github.io/dns/). This guide includes directions on integrating with GoDaddy.

If you are not using DNS to distribute your certificates (i.e., if you are going to use LDAP), you may use your registrar's DNS configuration tooling to set up MX records for your HISP.

## Distributing Certificates

The preferred mechanism for distributing your HISP's organizational (org) certificate is DNS CERT records. Instructions for setting up the Direct DNS server are in the DNS server deployment [guide](https://directprojectjavari.github.io/dns/).

**NOTE:** Some OS distributions, such as Ubuntu, may already be running their own DNS server process. If the OS is already running a DNS server bound to the DNS ports (TCP and UDP port 53), you will need to stop that service before running the Direct DNS server. For example, to determine if Ubuntu already has a DNS server running, run the following command and check for a process listening on the port:

```
netstat -anp | grep 53
```

Another alternative is LDAP. The default settings in the security and trust agent will attempt to use the Direct LDAP specification if SRV records can be found. The LDAP standards can be found on the S&I Framework's Certificate Discovery for Direct Project workgroup [page](https://docs.google.com/document/d/1igDpIizm7CTfV-fUw_1EnrCUGIljFEgLPRHpgK5iaec/edit).

A fallback alternative is manually distributing your org certificate to the HISPs you will communicate with. This is an out-of-band process that will require you to determine how to get your certificate to the HISP. Likewise, another HISP may need to manually give you their certificate(s) if they do not support DNS or LDAP discovery. To add another HISP's certificate (not anchor) to your HISP, import the certificate file into the Certificates section of the configuration UI tool.

## Recommended Next Steps

The following are optional, but recommended, next steps to secure your environment. These are only small configuration tweaks; other configuration options covering specific areas are described in the deployment options [section](imp-options).

#### Secure Internal Service Ports

To secure internal services, it is recommended that you limit access to the service ports to localhost and/or a local subnet.

#### Secure Configuration Service Password

To further protect the internal configuration service — especially if its ports must remain public — we recommend changing the default password for the configuration service. The default password is *direct*, and where you change it depends on your deployment model:

- Legacy Deployment

The default password is encrypted in the *`<tomcat home>`/webapps/config-ui/WEB-INF/classes/bootstrap.properties* file under the property *direct.configui.security.user.password*. You can change the password either by putting the new password in plain text (remove the {bcrypt} prefix before the password) or by creating an encrypted value using an online bcrypt web [tool](https://www.browserling.com/tools/bcrypt). **NOTE:** If you use an encrypted password in the properties file, be sure to leave the *{bcrypt}* prefix before the encrypted text.

Restart the Tomcat server for the changes to take effect.

- Cloud Native Deployment

The default password is contained within the code itself, but it can be overridden by creating an `application.properties` or `application.yaml` file in the same directory as the config-service.jar file and setting the password under the property *direct.configui.security.user.password*. You can change the password either by putting the new password in plain text (remove the {bcrypt} prefix before the password) or by creating an encrypted value using an online bcrypt web [tool](https://www.browserling.com/tools/bcrypt). **NOTE:** If you use an encrypted password in the properties file, be sure to leave the *{bcrypt}* prefix before the encrypted text.

You can use any other Spring configuration method to set the password property (you don't have to use an `application.properties` or `application.yaml` file), such as JVM parameters or even an external source like Spring Cloud Config.

Restart the configuration service process for the changes to take effect.

#### Add Own Server Certificate to Apache James (Legacy Only)

If you are using James 3, the default configuration enables last-mile encryption (SSL and TLS) on the edge POP3, SMTP, and IMAP protocols. This is configured in the imapserver.conf, pop3server.conf, and smtpserver.conf files. For POP3 and IMAP4, all connections use the STARTTLS command. For the SMTP protocol, the configuration enables STARTTLS for local outgoing connections that must be authenticated, but all incoming SMTP exchanges from external systems will continue to use non-SSL/TLS connections.

To enable encryption, a server certificate must be installed along with its private key. The James 3 configuration comes pre-packaged with a self-signed certificate, and most email and edge clients will warn the user that this certificate should not be trusted. At this point, we recommend installing either your own certificate or one issued by a trusted PKI third party. In either case, you will need to create your own keystore file containing your certificate and deploy it to the James conf directory — the same location where the default `cakeystore.jks` file resides. After deploying your own keystore, you will need to update the SSL connection section of the imapserver.xml, pop3server.xml, and smtpserver.xml files with the location of your own keystore file and its passphrase.

#### Tweak Message Monitoring Service Settings

The message monitoring service is preconfigured with common settings, but can be tweaked to your specific requirements. See the monitoring deployment [guide](https://directprojectjavari.github.io/direct-msg-monitor/DepAndConfig) for more details.

#### Define Policy Definitions

Starting with version 3.0, an optional module is available for defining X.509 certificate policies. See the policy enablement module's (direct-policy) [user guide](https://directprojectjavari.github.io/direct-policy/) for full details.


