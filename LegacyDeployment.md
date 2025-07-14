# Legacy HISP Deployment Model

The legacy model consists of Apache Tomcat running along with Apache James to deploy the HISP (save the DNS server which runs as
its own standalone service).  Each process runs the following services:

* Apache Tomcat:
  * Configuration Service
  * Configuration UI
  * Message Monitor
  * XD 
 
* Apache James:
  * SMTP, POP3, IMAP Protocols
  * XD Step Up/Step Down service
  * Security and Trust Agent (STA)

* DNS Server
  * Authoritative TCP/UDP DNS request/responses

For HISPs upgrading from older version of the Java Reference Implementation, utilizing this deployment model is likely preferable for ease
of migration.  Although the legacy deployment is a simpler model, the Cloud Native deployment model is recommended for new HISP implementations
as it is a more contemporary model and is supported by almost every Cloud Native platform type from Bare Metal to platforms such
as CloudFoundry and Kubernetes and even highly managed services such as Google Cloud Run.

The following steps will guide you throug the deployment process.

##  Obtain Reference Implementation Stock Assembly

The stock assembly contains all of the pre-assembled and configured components of the Bare Metal deployment. Download the latest version of the stock assembly from the maven central repository [repository](http://repo.maven.apache.org/maven2/org/nhind/direct-project-stock/6.0/direct-project-stock-6.0.tar.gz).

**Note:** The maven central repository may black list some IP ranges such as virutal machines running in the Amazon EC2 cloud. Use the Sonatype repository if you are blocked from the maven central repository.

The assembly contains a root directly named direct and has the following folders under the root.

* apache-tomcat-9.0.17
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

To start the tomcat server, run the following command from the DIRECT HOME/apache-tomcat-9.0.17/bin directory.

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

You should be presented with the configuration ui login screen.

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



