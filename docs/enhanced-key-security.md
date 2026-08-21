---
title: Enhanced Private Key Security
---

# Enhanced Private Key Security

Although version 4.0 of Bare Metal added additional protection for private keys, it only protected keys at rest. When keys were "activated," they were loaded into the agent's process memory completely unencrypted. Some deployments may lock down access to the agent tightly enough that this is acceptable, but it still leaves the keys vulnerable to any entity with access to the agent's process memory.

With governmental and other high-security agencies now implementing Direct, a higher level of key protection is required, not only by the agencies themselves, but by the systems that they rely upon (i.e., your system). A common approach to the private key protection problem is to utilize a PKCS11 token, such as a NIST-certified hardware security module, where the keys are only activated (i.e., utilized for cryptographic operations in their unencrypted form) inside the token. Beginning with version 5.0, Bare Metal supports PKCS11 tokens using this model.

**NOTE:** The following is an optional configuration; Bare Metal will still operate in the same manner as version 4.0 if the following configuration options are not implemented. If enhanced key security is implemented, any keys installed before implementation will continue to operate and function as they did in previous versions (the system is backward compatible). If you wish to use enhanced key security on previously installed keys, you will need to remove them and reimport them.

## Key-at-Rest Protection

Version 4.0 of Bare Metal first implemented key protection by encrypting p12 containers in the configuration service. The configuration service was configured with a secret key that could either be bootstrapped in the Spring configuration or loaded from a PKCS11 token. The private key was only encrypted when at rest and was decrypted as soon as it was read from the configuration store's database. This meant that the private key was accessible at any time it was outside of the configuration service, including when the private key was first loaded into the system.

To ensure that private keys always stay encrypted until they are needed for cryptographic operations, PKCS11 tokens utilize key "wrapping" and "unwrapping." Wrapping encrypts a private key using a symmetric secret key that is also stored and only activated in the PKCS11 module (it doesn't help to secure private keys at rest if their key encryption key is exposed). Unwrapping decrypts the private key using the same symmetric secret key; however, the unwrapping operation results in the private key being loaded into, and only decrypted inside, the PKCS11 token. The application using the private key is only given a logical handle to the secret key and can't get access to the sensitive key material.

Using the wrapping and unwrapping model, the configuration service is no longer responsible for encrypting and decrypting p12 files. Instead, certificates and their private keys are loaded into and retrieved from the configuration service in their wrapped form. The config-ui is now responsible for wrapping the private keys as they are loaded into the application, and the agent is responsible for unwrapping keys at the time they are needed for cryptographic operations.

## PKCS11 Token Selection

There are many PKCS11 options available on the market; however, it is recommended that you utilize a module that is NIST certified. Additionally, it MUST have support for the Java PKCS11 model and optimally support (though not required) wrapping private keys with an AES128 secret key. Value-adds to look for are good documentation, key management tooling, random number generation, and access from multiple nodes for high availability and scalability.

## Key Encryption Key

The first step is to create the symmetric key that will encrypt the private keys; this is also known as the key encryption key. The key encryption key is an AES128 key, and its generation is dependent on the tooling at hand. Some PKCS11 modules come with tools that enable creation of AES128 keys on the module; see your token's documentation for details. If your token does not have such a tool, Bare Metal ships with the PKCS11SecretKeyManager tool to create random AES128 keys. In either case, the key encryption key is assigned a name (or alias) that will be used by the agent (and optionally the config-ui) to reference the key encryption key.

#### PKCS11SecretKeyManager

The PKCS11SecretKeyManager accesses a PKCS11 token for the purpose of managing secret keys on the token. Before you can use the tool, you will need to check the documentation of your token to understand how it works with the Java PKCS11 model. There are generally two ways:

* The token utilizes the Sun PKCS11 JCE provider and is configured using a file that adheres to the Sun PKCS11 configuration [guide](https://docs.oracle.com/javase/7/docs/technotes/guides/security/p11guide.html). Most notably, this file contains the name of the native library that implements the token's bridge interface.
* The token ships its own PKCS11 JCE provider library. In this case, the configuration is completely dependent on the token vendor's implementation. In many cases, a file or input stream is passed to the KeyStore load method that contains configuration information.

The PKCS11SecretKeyManager supports both methods.

Some tokens may partially support the PKCS11 interface, but may require proprietary code to perform some operations. For example, the Gemalto (formerly SafeNet) ProtectServer HSM supports almost all of the functionality required by the Direct reference implementation through its PKCS11 interface; however, it does not support key wrapping without using a proprietary API. The reference implementation has attempted to fill these gaps on a case-by-case basis through the use of the direct-jce-providers.jar module. This module provides a wrapper/shim around the token's JCE implementation and fills in the missing functionality to make the PKCS11 implementation complete for the purposes of Direct.

The PKCS11SecretKeyManager has a couple of command-line arguments:

* -keyStoreCfg: This parameter is always required and is the path to a file that contains the following information:
  * JCE provider class name. This will be *sun.security.pkcs11.SunPKCS11* for tokens that utilize the Sun JCE provider. Tokens that implement their own providers should indicate the provider class name in their documentation.
  * Key Store Type: This is the type of key store. If not present, this defaults to PKCS11. Some tokens will require a proprietary name; see the token's documentation for details.
  * Key Store Source: For tokens that implement their own JCE providers, this is a string that is passed to the KeyStore load method.
* -pkcscfg: For tokens that utilize the *sun.security.pkcs11.SunPKCS11* JCE provider, this is a required parameter that is the path to a file that contains the Sun PKCS11-compliant configuration information.

The following is an example of the contents of the keyStoreCfg file for a token that uses the *sun.security.pkcs11.SunPKCS11* JCE provider:

```
keyStoreProviderName=sun.security.pkcs11.SunPKCS11
```

The following is an example of the contents of the keyStoreCfg file for a token that uses its own JCE provider:

```
keyStoreType=Luna
keyStoreProviderName=com.safenetinc.luna.provider.LunaProvider
keyStoreSource=slot:0
```

The following is an example of the contents of the required pkcscfg for a token that uses the *sun.security.pkcs11.SunPKCS11* JCE provider:

```
name=SafeNeteTokenPro
library=/usr/local/lib/libeTPkcs11.dylib
```

Once you have the proper configuration completed, you need to make sure you have all native libraries and jar files in the proper location. Most likely, the native libraries will be installed when you run the installation software package that came with your token. For tokens that utilize the *sun.security.pkcs11.SunPKCS11* JCE provider, you need to find the location of the native library that implements the Java PKCS11 bridge. For tokens that implement their own JCE providers, they will most likely have a combination of native libraries and a jar file. You will need to add the jar file to the Bare Metal /tools/lib directory.

The following is an example command to launch the tool for a token that uses the *sun.security.pkcs11.SunPKCS11* JCE provider:

```
./keyStoreMgr.sh -keyStoreCfg keyStore.cfg -pkcscfg pkcs11.cfg
```

The following is an example command to launch the tool for a token that uses its own JCE provider. Note it does not need a pkcscfg file:

```
./keyStoreMgr.sh -keyStoreCfg keyStore.cfg
```

Once you launch the tool and enter the correct pin/password, creating a random secret key is done by executing the following command. In most cases, using this command will utilize a random number generator implemented on the token. **NOTE:** You can use any key name you want, but it MUST match the key alias name in the config-ui and gateway (agent) configuration files.

```
CreateRandomSecretKey privateKeyWrapperSecrets
```

## Config UI Configuration

When importing unencrypted keys with enhanced key protection, the config-ui can wrap unencrypted keys before sending them to the configuration service. **NOTE:** This is not the preferred method when using key wrapping. A more appropriate approach is to generate the keys on the HSM, export/wrap the keys using the PKCS11SecretKeyManager tool, and import the wrapped key into the configuration service using the config-ui (or the ConfigManage command-line tool). If you export/wrap the keys using the PKCS11SecretKeyManager tool, the configuration in the paragraphs below is not necessary.

In order to do this, the config-ui web application will need access to the PKCS11 token. The token is configured similarly to the way it is configured for the [gateway](https://directprojectjavari.github.io/gateway/PKCS11Configuration). To configure the token, you will need to add properties to the bootstrap.properties file in the `<tomcat home>`/webapps/config-ui/WEB-INF/classes/properties directory. Once these properties are set, you will need to restart Tomcat.

Similar to the PKCS11SecretKeyManager tool, you will need to make sure all native libraries are properly installed. If the token implements its own JCE provider, you need to copy the vendor's jar file to the `<tomcat home>`/webapps/config-ui/WEB-INF/lib directory.

## Gateway and Agent Configuration

To properly unwrap the keys and utilize the token, the gateway (and subsequently the agent) also needs to be configured. Documentation for configuring PKCS11 tokens for the gateway is [here](https://directprojectjavari.github.io/gateway/PKCS11Configuration).

You will again need to ensure that the appropriate token native libraries are installed and any jar files copied to the following location:

* `<DIRECTHOME>`/james-jpa-guice-3.2.0/james-server-jpa-guice.lib

## Example Workflow for Creating and Importing Certificates and Keys

The preferred methodology for creating and importing keys is to generate the public/private key pair on the HSM and import the wrapped private key, along with its certificate, into the configuration service using the config-ui or the ConfigManager command-line tool. Going from creating a public/private key pair to ultimately having a signed certificate from a CA takes a few steps; these steps are outlined below and utilize the PKCS11SecretKeyManager tool. These steps assume that you have properly configured the PKCS11SecretKeyManager tool to communicate with your HSM using the steps in the PKCS11SecretKeyManager section of this document.

#### Secret Key Creation

All enhanced key protection is done with an AES128 secret key. To create a secret key, you can use the CREATERANDOMSECRETKEY or CREATEUSERSECRETKEY commands. Using CREATERANDOMSECRETKEY utilizes the random number generation functionality (if available) of your HSM to create a new random secret key; this is the preferred method. The example below creates a secret key using a key name that matches the default configuration in the gateway (agent) and the default optional configuration of the config-ui.

```
CREATERANDOMSECRETKEY privateKeyWrapperSecret
```

To verify that the secret key was created, issue the following command:

```
listsecretkeys
```

#### Key Pair Creation

The first step to creating any certificate for use with Direct is to create a public/private key pair. Once you have launched the PKCS11SecretKeyManager tool, you create a key pair by using the CREATEKEYPAIR command. With this command, you give the key pair a name with an optional key size (defaults to 2048). The key pair name will be used in subsequent commands to generate a CSR and to export/wrap the private key. The example command below creates a key pair named "directSecEmailDigSig" with a key length of 2048 bits. **NOTE:** If you are creating certificates with single-use keys, you need to create a key pair for the encryption certificate and a key pair for the digital signature certificate.

```
CREATEKEYPAIR directSecEmailDigSig	
```

To verify that the key pair was created, issue the following command (this will show both RSA key pairs and secret keys):

```
listallkeys
```

#### CSR Creation and CSR Signing

Now that you have a key pair, you can generate a certificate signing request (CSR) that can be uploaded to a third-party CA or other CA signing tool for certificate creation. To generate a CSR, use the CREATECSR command to specify the attributes that you want in the certificate. The sample command below creates a CSR for a single-use encryption certificate using the directSecEmailDigSig key pair generated in the previous section for a domain-level certificate named direct.securehealthemail.com. **NOTE:** If you are creating certificates with single-use keys, you will create two CSRs using the exact same attributes, with the exception that the key usage and key pair parameters will be different.

```
CREATECSR directSecEmailDigSig direct.securehealthemail.com direct.securehealthemail.com KeyEncipherment C=US S=Missouri "L=Kansas City" "O=Direct RI"
```

Once you execute this command, the tool will create a PEM-encoded CSR file that you can submit to your CA for signing. For testing purposes, the reference implementation's certGen tool can now sign CSR files to generate a certificate.

#### Export/Wrap the Private Key

The next step is to export the private key from the system. This step will utilize the AES128 secret to encrypt the private key and export the encrypted private key to a file. The following example command wraps the private key associated with the directSecEmailDigSig key pair using the privateKeyWrapperSecret secret key. You can optionally provide a name for the wrapped key file, but the system will auto-generate one if you don't provide a file name.

```
EXPORTPRIVATEKEY directSecEmailDigSig privateKeyWrapperSecret
```

Once you execute this command, the tool will create a file containing the wrapped private key. You will import this wrapped key file, along with the signed certificate from the previous section, into the configuration service utilizing either the config-ui or the ConfigManager command-line tool.

#### Importing the Wrapped Key and Certificate

Now that you have a wrapped key and signed certificate, it's time to import the key and certificate into the system for use by the security and trust agent and Direct message exchange. You have two ways to import the files. If you are using the config-ui, starting with version 5.1 of the stock assembly, you can import the wrapped key and certificate files into the system using the config-ui's certificate tab. If you prefer to use the ConfigMgmtConsole command-line tool, you can import the wrapped private key file and certificate file into the system using the ADDPRIVATECERTWITHWRAPPEDKEY command. The example command below imports a certificate file and wrapped key into the system.

```
ADDPRIVATECERTWITHWRAPPEDKEY directSecureHealthEmail_encCert.der directSecEmailDigSig-privKey.der
```

The certificate and private key are ready to be used by your Direct implementation.

#### Clean Up

Once you have imported the private key and certificate into your system, it's most likely not necessary for the key pair to remain in the HSM (unless you need it later for reissuing certificates with the same key pair). Most HSMs have limited storage, so it's a good idea to clean up your key pair once you're done. To remove a key pair from the HSM, use the REMOVEKEY command. The example command below deletes the key pair generated earlier in the section from the HSM.

```
REMOVEKEY directSecEmailDigSig
```

